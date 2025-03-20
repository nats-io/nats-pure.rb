# frozen_string_literal: true

RSpec.describe NATS::JetStream::ConsumerMessage do
  before(:all) do
    @server = NatsServerControl.new(
      "nats://127.0.0.1:4222",
      "/tmp/test-nats.pid",
      "-js"
    )
    @server.start_server(true)
  end

  after(:all) do
    @server.kill_server
  end

  let(:js) { NATS::JetStream::Context.new(client) }

  describe "#bytes" do
    subject { described_class.build(consumer, message) }

    let(:consumer) { NATS::JetStream::Consumer.new(stream, name: "consumer") }
    let(:stream) { NATS::JetStream::Stream.new(js, name: "stream") }
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

  describe "acks" do
    subject { consumer.next(expires: 1.to_nsec) }

    let!(:stream) { js.streams.create(name: "stream") }
    let(:consumer) { stream.consumers.upsert(name: "consumer", ack_wait: 100) }
    let(:client) { NATS.connect }

    let(:next_message) { consumer.next(expires: 1.to_nsec) }

    before { js.publish("stream", "data") }

    after do
      consumer.delete
      stream.delete
    end

    describe "#acked?" do
      context "when messages has been acked" do
        before { subject.ack }

        it "returns true" do
          expect(subject.acked?).to be(true)
        end
      end

      context "when messages has not been acked yet" do
        it "returns false" do
          expect(subject.acked?).to be(false)
        end
      end
    end

    describe "#ack" do
      it "acks message" do
        subject.ack

        expect(subject.acked?).to be(true)
        expect(next_message).to be(nil)
      end
    end

    describe "#nack" do
      it "nacks message" do
        subject.nack

        expect(subject.acked?).to be(true)
        expect(next_message).to be
      end
    end

    describe "#term" do
      it "terms message" do
        subject.term

        expect(subject.acked?).to be(true)
        expect(next_message).to be(nil)
      end
    end

    describe "#in_progress" do
      it "marks message as in progress" do
        subject.in_progress

        expect(subject.acked?).to be(false)
        expect(next_message).to be
      end
    end
  end
end
