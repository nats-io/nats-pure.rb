# frozen_string_literal: true

RSpec.describe NATS::JetStream::Consume::Connection do
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
    NATS::JetStream::Message.new(
      consumer,
      NATS::Msg.new(
        subject: "subject",
        header: {},
        data: "data",
        reply: "$JS.ACK.stream.consumer.3.2795.3495.1744033099995368000.7"
      )
    )
  end

  let(:heartbeats) { pull.heartbeats.send(:task) }

  before do
    allow(pull).to receive(:request_messages)
    allow(pull).to receive(:stop).and_call_original
  end

  describe "#start" do
    after { subject.stop }

    it "starts connection monitoring" do
      subject.start

      expect(Thread.list).to include(
        have_attributes(name: "nats:js-consume-#{subject.object_id}")
      )
    end
  end

  describe "#stop" do
    before { subject.start }

    it "closes status listener" do
      subject.stop

      expect(subject.status_listener.closed?).to be(true)
    end

    it "cancels connection monitoring" do
      subject.stop
      sleep 0.1

      expect(subject.thread.status).to be(false)
    end
  end

  describe "#handle" do
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

        expect(heartbeats.rejected?).to be(true)
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

        expect(heartbeats.pending?).to be(true)
      end

      it "resets buffer" do
        reconnected

        expect(pull.buffer).to have_attributes(
          messages_pending: 100,
          bytes_pending: nil
        )
      end
    end

    context "when client has been closed" do
      it "drains pull" do
        client.close
        sleep 0.1

        expect(pull).to have_received(:stop)
      end
    end
  end
end
