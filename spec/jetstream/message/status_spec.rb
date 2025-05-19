# frozen_string_literal: true

RSpec.describe NATS::JetStream::WarningMessage do
  subject { described_class.new(consumer, message) }

  let(:consumer) { NATS::JetStream::Consumer.new(stream, name: "consumer") }
  let(:stream) { NATS::JetStream::Stream.new(js, name: "stream") }

  let(:js) { NATS::JetStream::Context.new(client) }
  let(:client) { double(NATS::Client) }

  let(:message) do
    NATS::Msg.new(
      subject: "subject",
      header: {
        "Status" => "409",
        "Description" => "Batch Completed",
        "Nats-Pending-Messages" => nats_pending_messages,
        "Nats-Pending-Bytes" => nats_pending_bytes
      },
      data: "data",
      reply: "inbox"
    )
  end

  let(:nats_pending_messages) { "5" }
  let(:nats_pending_bytes) { "50" }

  describe "#pull_termintated?" do
    context "when Nats-Pending-Messages is present" do
      let(:nats_pending_messages) { "5" }
      let(:nats_pending_bytes) { nil }

      it "returns true" do
        expect(subject.pull_terminated?).to be(true)
      end
    end

    context "when Nats-Pending-Bytes is present" do
      let(:nats_pending_messages) { nil }
      let(:nats_pending_bytes) { "5" }

      it "returns true" do
        expect(subject.pull_terminated?).to be(true)
      end
    end

    context "when both Nats-Pending-Messages and Nats-Pending-Bytes are blank" do
      let(:nats_pending_messages) { nil }
      let(:nats_pending_bytes) { nil }

      it "returns false" do
        expect(subject.pull_terminated?).to be(false)
      end
    end
  end

  describe "#pending_messages" do
    context "when Nats-Pending-Messages is present" do
      let(:nats_pending_messages) { "5" }

      it "returns Nats-Pending-Messages values as integer" do
        expect(subject.pending_messages).to eq(5)
      end
    end

    context "when Nats-Pending-Messages is blank" do
      let(:nats_pending_messages) { nil }

      it "returns 0" do
        expect(subject.pending_messages).to eq(0)
      end
    end
  end

  describe "#pending_bytes" do
    context "when Nats-Pending-Bytes is present" do
      let(:nats_pending_bytes) { "5" }

      it "returns Nats-Pending-Bytes values as integer" do
        expect(subject.pending_bytes).to eq(5)
      end
    end

    context "when Nats-Pending-Bytes is blank" do
      let(:nats_pending_bytes) { nil }

      it "returns 0" do
        expect(subject.pending_bytes).to eq(0)
      end
    end
  end
end
