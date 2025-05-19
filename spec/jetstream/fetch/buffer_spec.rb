# frozen_string_literal: true

RSpec.describe NATS::JetStream::Fetch::Buffer do
  subject { described_class.new(pull) }

  let(:pull) { NATS::JetStream::Fetch.new(consumer, params) }

  let(:consumer) { NATS::JetStream::Consumer.new(stream, name: "consumer") }
  let(:stream) { NATS::JetStream::Stream.new(js, name: "stream") }

  let(:js) { NATS::JetStream::Context.new(client) }
  let(:client) { double(NATS::Client, new_inbox: "inbox") }

  let(:params) { {} }

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

  describe "#initialize" do
    it "sets messages to an empty array" do
      expect(subject.messages).to eq([])
    end

    it "sets messages_fetched to 0" do
      expect(subject.messages_fetched).to eq(0)
    end

    it "sets bytes_fetched to 0" do
      expect(subject.bytes_fetched).to eq(0)
    end
  end

  describe "#reset" do
    before { subject.fetched(message) }

    it "sets messages to an empty array" do
      subject.reset

      expect(subject.messages).to eq([])
    end

    it "sets messages_fetched to 0" do
      subject.reset

      expect(subject.messages_fetched).to eq(0)
    end

    it "sets bytes_fetched to 0" do
      subject.reset

      expect(subject.bytes_fetched).to eq(0)
    end
  end

  describe "#fetched" do
    let(:fetched) { subject.fetched(message) }

    it "adds message to messages" do
      fetched

      expect(subject.messages).to include(message)
    end

    it "increments messages_fetched" do
      fetched

      expect(subject.messages_fetched).to eq(1)
    end

    it "adds message bytesize to bytes_fetched" do
      fetched

      expect(subject.bytes_fetched).to eq(68)
    end
  end

  describe "#full?" do
    context "when max_messages is provided" do
      let(:params) { {max_messages: 3} }

      context "when messages_fetched < max_messages" do
        it "returns false" do
          expect(subject.full?).to eq(false)
        end
      end

      context "when messages_fetched = max_messages" do
        before do
          3.times { subject.fetched(message) }
        end

        it "returns true" do
          expect(subject.full?).to eq(true)
        end
      end

      context "when messages_fetched > max_messages" do
        before do
          5.times { subject.fetched(message) }
        end

        it "returns true" do
          expect(subject.full?).to eq(true)
        end
      end
    end

    context "when max_bytes is provided" do
      let(:params) { {max_bytes: 204} }

      context "when bytes_fetched < max_bytes" do
        before { subject.fetched(message) }

        it "returns false" do
          expect(subject.full?).to eq(false)
        end
      end

      context "when bytes_fetched = max_bytes" do
        before do
          3.times { subject.fetched(message) }
        end

        it "returns true" do
          expect(subject.full?).to eq(true)
        end
      end

      context "when bytes_fetched > max_bytes" do
        before do
          5.times { subject.fetched(message) }
        end

        it "returns true" do
          expect(subject.full?).to eq(true)
        end
      end
    end
  end
end
