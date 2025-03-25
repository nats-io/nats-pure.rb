# frozen_string_literal: true

RSpec.describe NATS::JetStream::Fetch::Heartbeats do
  subject { described_class.new(pull) }

  let(:pull) { NATS::JetStream::Fetch.new(consumer, params) }
  let(:params) { {expires: 5.to_nsec, idle_heartbeat: 1.to_nsec} }

  let(:consumer) { NATS::JetStream::Consumer.new(stream, name: "consumer") }
  let(:stream) { NATS::JetStream::Stream.new(js, name: "stream") }

  let(:js) { NATS::JetStream::Context.new(client) }
  let(:client) { double(NATS::Client, new_inbox: "inbox") }

  let(:heartbeats) { subject.send(:task) }

  before { allow(pull).to receive(:drain) }

  describe "#start" do
    after { subject.stop }

    it "sets heartbeat timer as 2 * idle_heartbeat" do
      subject.start

      expect(heartbeats.schedule_time).to be >= Concurrent.monotonic_time + 1.95
    end
  end

  describe "#stop" do
    before { subject.start }

    it "cancels heartbeat timer" do
      subject.stop

      expect(heartbeats.rejected?).to eq(true)
    end
  end

  describe "#handle" do
    before { subject.start }
    after { subject.stop }

    let(:params) { {idle_heartbeat: 0.5.to_nsec} }

    it "sets error to No Heartbeats and drains pull" do
      sleep 1.25

      expect(pull).to have_received(:drain).with(NATS::JetStream::NoHeartbeatError)
    end
  end
end
