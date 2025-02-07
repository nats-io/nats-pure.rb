# frozen_string_literal: true

RSpec.describe NATS::JetStream::ConsumerMessage do
  subject { described_class.build(consumer, message) }

  let(:consumer) { NATS::JetStream::Consumer.new(stream, name: "consumer") }
  let(:stream) { NATS::JetStream::Stream.new(js, name: "stream") }

  let(:js) { NATS::JetStream::Context.new(client) }
  let(:client) { double(NATS::Client) }

  let(:message) do
    NATS::Msg.new(
      subject: "subject",
      raw_header: header,
      data: data,
      reply: reply
    )
  end

  let(:header) {}
  let(:data) {}
  let(:reply) {}

  describe "#bytes" do
    context "when only subject is present" do
      it "returns subject bytesize" do
        expect(subject.bytesize).to eq(7)
      end
    end

    context "when headers are present" do
      let(:header) do
        "NATS/1.0 408 Request Timeout\nNats-Pending-Messages: 5\nNats-Pending-Bytes: 0\r\n"
      end

      it "includes raw header bytesize" do
        expect(subject.bytesize).to eq(84)
      end
    end

    context "when data is present" do
      let(:data) { "data" }

      it "includes data bytesize" do
        expect(subject.bytesize).to eq(11)
      end
    end

    context "when reply is present" do
      let(:reply) { "inbox" }

      it "includes reply bytesize" do
        expect(subject.bytesize).to eq(12)
      end
    end

    context "when headers, data and reply are present" do
      let(:header) do
        "NATS/1.0 408 Request Timeout\nNats-Pending-Messages: 5\nNats-Pending-Bytes: 0\r\n"
      end

      let(:data) { "data" }
      let(:reply) { "inbox" }

      it "returns the sum of all of them" do
        expect(subject.bytesize).to eq(93)
      end
    end
  end

  describe "#acked?" do
  end

  describe "#ack" do
  end
end
