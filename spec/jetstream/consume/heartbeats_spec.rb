# frozen_string_literal: true

RSpec.describe NATS::JetStream::Consume::Heartbeats do
  subject { described_class.new(pull) }

  let(:pull) { NATS::JetStream::Consume.new(consumer, params) }
  let(:params) { {expires: 5.to_nsec, idle_heartbeat: 1.to_nsec} }

  let(:consumer) { NATS::JetStream::Consumer.new(stream, name: "consumer") }
  let(:stream) { NATS::JetStream::Stream.new(js, name: "stream") }

  let(:js) { NATS::JetStream::Context.new(client) }
  let(:client) { double(NATS::Client, new_inbox: "inbox") }

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

  let(:heartbeats) { subject.send(:task) }

  before do
    allow(pull).to receive(:request_messages)
  end

  describe "#start" do
    after { subject.stop }

    it "schedules heartbeats after 2 * idle_heartbeat" do
      subject.start

      expect(heartbeats.schedule_time).to be_within(Concurrent.monotonic_time + 2).of(0.05)
    end
  end

  describe "#stop" do
    before { subject.start }

    it "cancels heartbeats" do
      subject.stop

      expect(heartbeats.rejected?).to be(true)
    end
  end

  describe "#handle" do
    before { subject.start }
    after { subject.stop }

    before { pull.buffer.consumed(message) }

    let(:params) { {idle_heartbeat: 0.5.to_nsec} }

    it "requests messages and resets buffer and heartbeats" do
      sleep 1.25

      # requests new messages
      expect(pull).to have_received(:request_messages)

      # resets heartbeats
      expect(heartbeats.pending?).to be(true)

      # resets buffer
      expect(pull.buffer).to have_attributes(
        messages_pending: 100,
        bytes_pending: nil
      )
    end
  end

  describe "#reset" do
    context "when in unscheduled state" do
      it "does not set any schedule time" do
        subject.reset

        expect(heartbeats.schedule_time).to be(nil)
      end
    end

    context "when in pending state" do
      before { subject.start }
      after { subject.stop }

      it "resets the existing task" do
        sleep 0.5
        subject.reset

        expect(heartbeats.schedule_time).to be_within(Concurrent.monotonic_time + 2).of(0.05)
      end
    end

    context "when in processing state" do
      before do
        allow(heartbeats).to receive(:state).and_return(:processing)
      end

      it "schedules a new task" do
        subject.reset

        expect(subject.send(:task)).to_not eq(heartbeats)
      end
    end

    context "when in any other state state" do
      before { subject.stop }

      it "does not do anything" do
        subject.reset

        expect(heartbeats.rejected?).to be(true)
      end
    end
  end
end
