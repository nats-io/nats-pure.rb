# frozen_string_literal: true

RSpec.describe NATS::JetStream::Consume::Monitor do
  before(:all) do
    @server = NatsServerControl.new
    @server.start_server(true)
  end

  after(:all) do
    @server.kill_server
  end

  subject { described_class.new(pull) }

  let(:pull) { NATS::JetStream::Consume.new(consumer, params) }
  let(:params) { {expires: 5.to_nsec, idle_heartbeat: 1.to_nsec} }

  let(:consumer) { NATS::JetStream::Consumer.new(stream, name: "consumer") }
  let(:stream) { NATS::JetStream::Stream.new(js, name: "stream") }

  let(:js) { NATS::JetStream::Context.new(client) }
  let(:client) { NATS.connect }

  let(:message) do
    NATS::JetStream::ConsumerMessage.new(
      consumer,
      NATS::Msg.new(
        subject: "subject",
        header: {},
        data: "data",
        reply: "inbox"
      )
    )
  end

  before do
    allow(pull).to receive(:request_messages)
  end

  describe "#start" do
    after { subject.stop }

    it "schedules heartbeats after 2 * idle_heartbeat" do
      subject.start

      expect(subject.heartbeats.schedule_time).to be >= Concurrent.monotonic_time + 1.95
    end

    it "starts connection monitoring" do
      subject.start

      expect(Thread.list).to include(
        have_attributes(name: "nats::js::consume::#{subject.object_id}")
      )
    end
  end

  describe "#stop" do
    before { subject.start }

    it "cancels heartbeats" do
      subject.stop

      expect(subject.heartbeats.rejected?).to be(true)
    end

    it "closes status listener" do
      subject.stop

      expect(subject.status_listener.closed?).to be(true)
    end

    it "cancels connection monitoring" do
      subject.stop
      sleep 0.1

      expect(subject.connection.status).to be(false)
    end
  end

  describe "no heartbeats" do
    before { subject.start }
    after { subject.stop }

    before { pull.buffer.consumed(message) }

    let(:params) { {idle_heartbeat: 0.5.to_nsec} }

    it "requests messages and resets buffer and heartbeats" do
      sleep 1.25

      # requests new messages
      expect(pull).to have_received(:request_messages)

      # resets heartbeats
      expect(subject.heartbeats.pending?).to be(true)

      # resets buffer
      expect(pull.buffer).to have_attributes(
        messages_pending: 100,
        bytes_pending: nil
      )
    end
  end

  describe "connection" do
    before { subject.start }
    after { subject.stop }

    before { pull.buffer.consumed(message) }

    context "when client is reconnecting" do
      let(:reconnecting) do
        client.status_listeners.send(NATS::Status::RECONNECTING)
        sleep 0.1
      end

      it "stops heartbeats" do
        reconnecting

        expect(subject.heartbeats.rejected?).to be(true)
      end
    end

    context "when client has reconnected" do
      let(:reconnected) do
        client.status_listeners.send(NATS::Status::RECONNECTING)
        client.status_listeners.send(NATS::Status::CONNECTED)

        sleep 0.1
      end

      it "requests new messages" do
        reconnected

        expect(pull).to have_received(:request_messages)
      end

      it "resets heartbeats" do
        reconnected

        expect(subject.heartbeats.pending?).to be(true)
      end

      it "resets buffer" do
        reconnected

        expect(pull.buffer).to have_attributes(
          messages_pending: 100,
          bytes_pending: nil
        )
      end
    end
  end
end
