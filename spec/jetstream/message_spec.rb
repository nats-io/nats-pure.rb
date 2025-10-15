# frozen_string_literal: true

RSpec.describe NATS::JetStream::Message do
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

  describe "#bytesize" do
    subject { described_class.build(consumer, message) }

    let(:consumer) { NATS::JetStream::Consumer.new(stream, name: "consumer") }
    let(:stream) { NATS::JetStream::Stream.new(js, name: "stream") }
    let(:client) { double(NATS::Client) }

    let(:message) do
      NATS::Msg.new(
        subject: "subject",
        raw_header: header,
        data: data,
        reply: "$JS.ACK.stream.consumer.3.2795.3495.1744033099995368000.7"
      )
    end

    let(:header) {}
    let(:data) {}

    context "when only subject is present" do
      it "returns subject bytesize" do
        expect(subject.bytesize).to eq(64)
      end
    end

    context "when headers are present" do
      let(:header) do
        "NATS/1.0 408 Request Timeout\nNats-Pending-Messages: 5\nNats-Pending-Bytes: 0\r\n"
      end

      it "includes raw header bytesize" do
        expect(subject.bytesize).to eq(141)
      end
    end

    context "when data is present" do
      let(:data) { "data" }

      it "includes data bytesize" do
        expect(subject.bytesize).to eq(68)
      end
    end

    context "when headers and data are present" do
      let(:header) do
        "NATS/1.0 408 Request Timeout\nNats-Pending-Messages: 5\nNats-Pending-Bytes: 0\r\n"
      end

      let(:data) { "data" }

      it "returns the sum of all of them" do
        expect(subject.bytesize).to eq(145)
      end
    end
  end

  describe "json" do
    subject { described_class.build(consumer, message) }

    let(:consumer) { NATS::JetStream::Consumer.new(stream, name: "consumer") }
    let(:stream) { NATS::JetStream::Stream.new(js, name: "stream") }
    let(:client) { double(NATS::Client) }

    let(:message) do
      NATS::Msg.new(
        subject: "subject",
        raw_header: {},
        data: data,
        reply: "$JS.ACK.stream.consumer.3.2795.3495.1744033099995368000.7"
      )
    end

    context "when data is a valid JSON" do
      let(:data) { {key: :value}.to_json }

      it "parses data as JSON" do
        expect(subject.json).to eq(key: "value")
      end
    end

    context "when data is not a valid JSON" do
      let(:data) { "invalid" }

      it "raises JSON::ParserError" do
        expect { subject.json }.to raise_error(JSON::ParserError)
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

  describe "#metadata" do
    subject { described_class.build(consumer, message) }

    let(:consumer) { NATS::JetStream::Consumer.new(stream, name: "consumer") }
    let(:stream) { NATS::JetStream::Stream.new(js, name: "stream") }
    let(:client) { double(NATS::Client) }

    let(:message) do
      NATS::Msg.new(
        subject: "subject",
        raw_header: nil,
        data: "data",
        reply: "$JS.ACK.stream.consumer.3.2795.3495.1744033099995368000.7"
      )
    end

    it "returns metadata" do
      expect(subject.metadata).to be_a(NATS::JetStream::Message::Metadata)
    end
  end
end
