# frozen_string_literal: true

RSpec.describe NATS::Object::Chunk do
  subject { described_class.new(message) }

  let(:message) { NATS::JetStream::Message.new(consumer, msg) }

  let(:consumer) { NATS::JetStream::Consumer.new(stream, name: "consumer") }
  let(:stream) { NATS::JetStream::Stream.new(js, name: "stream") }

  let(:js) { NATS::JetStream::Context.new(client) }
  let(:client) { double(NATS::Client) }

  let(:msg) do
    NATS::Msg.new(
      subject: "subject",
      header: {},
      raw_header: "raw_header",
      data: "data",
      reply: reply
    )
  end

  let(:reply) { "$JS.ACK.stream.consumer.3.2795.3495.1744033099995368000.7" }

  describe "#data" do
    it "returns message data" do
      expect(subject.data).to eq("data")
    end
  end

  describe "#last?" do
    context "when num_pending is zero" do
      let(:reply) { "$JS.ACK.stream.consumer.3.2795.3495.1744033099995368000.0" }

      it "returns true" do
        expect(subject.last?).to be(true)
      end
    end

    context "when num_pending is not zero" do
      it "returns false" do
        expect(subject.last?).to be(false)
      end
    end
  end
end
