# frozen_string_literal: true

RSpec.describe NATS::JetStream::Fetch::Timeout do
  subject { described_class.new(pull) }

  let(:pull) { NATS::JetStream::Fetch.new(consumer, params) }
  let(:params) { {expires: 5.to_nsec, idle_heartbeat: 1.to_nsec} }

  let(:consumer) { NATS::JetStream::Consumer.new(stream, name: "consumer") }
  let(:stream) { NATS::JetStream::Stream.new(js, name: "stream") }

  let(:js) { NATS::JetStream::Context.new(client) }
  let(:client) { double(NATS::Client, new_inbox: "inbox") }

  let(:timeout) { subject.send(:task) }

  before { allow(pull).to receive(:stop) }

  describe "#start" do
    after { subject.stop }

    it "sets timeout timer as expires" do
      subject.start

      expect(timeout.schedule_time).to be >= Concurrent.monotonic_time + 4.95
    end
  end

  describe "#stop" do
    before { subject.start }

    it "cancels timeout timer" do
      subject.stop

      expect(timeout.rejected?).to eq(true)
    end
  end

  describe "#handle" do
    before { subject.start }
    after { subject.stop }

    let(:params) { {expires: 1.to_nsec} }

    it "sets error to Request Timeout and drains pull" do
      sleep 2.25

      expect(pull).to have_received(:stop).with(NATS::JetStream::PullTimeoutError)
    end
  end
end
