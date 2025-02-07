# frozen_string_literal: true

RSpec.describe NATS::JetStream::Consume::Buffer do
  before(:all) do
    @server = NatsServerControl.new
    @server.start_server(true)
  end

  after(:all) do
    @server.kill_server
  end

  subject { described_class.new(pull) }

  let(:pull) { NATS::JetStream::Consume.new(consumer, params) }

  let(:consumer) { NATS::JetStream::Consumer.new(stream, name: "consumer") }
  let(:stream) { NATS::JetStream::Stream.new(js, name: "stream") }

  let(:js) { NATS::JetStream::Context.new(client) }
  let(:client) { NATS.connect }

  let(:params) { {} }

  let(:message) do
    NATS::JetStream::ConsumerMessage.new(
      consumer,
      NATS::Msg.new(
        subject: "subject",
        header: {},
        data: "data",
        reply: "inbox"
      )
    )
  end

  describe "#initialize" do
    it "sets messages_fetched to 0" do
      expect(subject.messages_fetched).to eq(0)
    end

    context "when max_messages is set" do
      let(:params) { {max_messages: 100} }

      it "sets messages_pending to config.max_messages" do
        expect(subject.messages_pending).to eq(100)
      end

      it "sets bytes_pending to nil" do
        expect(subject.bytes_pending).to eq(nil)
      end
    end

    context "when max_bytes is set" do
      let(:params) { {max_bytes: 100} }

      it "sets messages_pending to 1_000_000" do
        expect(subject.messages_pending).to eq(1_000_000)
      end

      it "sets bytes_pending to config.max_bytes" do
        expect(subject.bytes_pending).to eq(100)
      end
    end
  end

  describe "#reset" do
    before { subject.consumed(message) }

    context "when max_messages is set" do
      let(:params) { {max_messages: 100} }

      it "sets messages_pending to config.max_messages" do
        subject.reset

        expect(subject.messages_pending).to eq(100)
      end

      it "sets bytes_pending to nil" do
        subject.reset

        expect(subject.bytes_pending).to eq(nil)
      end
    end

    context "when max_bytes is set" do
      let(:params) { {max_bytes: 100} }

      it "sets messages_pending to 1_000_000" do
        subject.reset

        expect(subject.messages_pending).to eq(1_000_000)
      end

      it "sets bytes_pending to config.max_bytes" do
        subject.reset

        expect(subject.bytes_pending).to eq(100)
      end
    end
  end

  describe "#consumed" do
    let(:consumed) { subject.consumed(message) }

    it "increments messages_fetched" do
      consumed

      expect(subject.messages_fetched).to eq(1)
    end

    context "when max_messages is set" do
      let(:params) { {max_messages: 100} }

      it "decrement messages_pending by 1" do
        consumed

        expect(subject.messages_pending).to eq(99)
      end

      it "does not change bytes_pending" do
        consumed

        expect(subject.bytes_pending).to eq(nil)
      end
    end

    context "when max_bytes is set" do
      let(:params) { {max_bytes: 100} }

      it "decrement max_messages by 1" do
        consumed

        expect(subject.messages_pending).to eq(999_999)
      end

      it "decrements bytes_pending by message.bytesize" do
        consumed

        expect(subject.bytes_pending).to eq(84)
      end
    end
  end

  describe "#depleting?" do
    context "when max_messages is provided" do
      let(:params) { {max_messages: 4} }

      context "when messages_pending > threshold_messages" do
        it "returns false" do
          expect(subject.depleting?).to eq(false)
        end
      end

      context "when messages_pending = threshold_messages" do
        before do
          2.times { subject.consumed(message) }
        end

        it "returns true" do
          expect(subject.depleting?).to eq(true)
        end
      end

      context "when messages_pending < threshold_messages" do
        before do
          3.times { subject.consumed(message) }
        end

        it "returns true" do
          expect(subject.depleting?).to eq(true)
        end
      end
    end

    context "when max_bytes is provided" do
      let(:params) { {max_bytes: 100} }

      before do
        pull.config.update(
          max_messages: max_messages,
          threshold_messages: threshold_messages
        )
      end

      let(:max_messages) { 4 }

      context "when bytes_pending > threshold_bytes" do
        context "and messages_pending > threshold_messages" do
          let(:threshold_messages) { 1 }

          it "returns false" do
            expect(subject.depleting?).to eq(false)
          end
        end

        context "and messages_pending = threshold_messages" do
          let(:threshold_messages) { 2 }

          before do
            2.times { subject.consumed(message) }
          end

          it "returns true" do
            expect(subject.depleting?).to eq(true)
          end
        end

        context "and messages_pending < threshold_messages" do
          let(:threshold_messages) { 3 }

          before do
            2.times { subject.consumed(message) }
          end

          it "returns true" do
            expect(subject.depleting?).to eq(true)
          end
        end
      end

      context "when bytes_pending = threshold_bytes" do
        let(:params) { {max_bytes: 64} }

        before do
          2.times { subject.consumed(message) }
        end

        context "and messages_pending > threshold_messages" do
          let(:threshold_messages) { 1 }

          it "returns false" do
            expect(subject.depleting?).to eq(true)
          end
        end

        context "and messages_pending = threshold_messages" do
          let(:threshold_messages) { 2 }

          it "returns true" do
            expect(subject.depleting?).to eq(true)
          end
        end

        context "and messages_pending < threshold_messages" do
          let(:threshold_messages) { 3 }

          it "returns true" do
            expect(subject.depleting?).to eq(true)
          end
        end
      end

      context "when bytes_pending < threshold_bytes" do
        let(:params) { {max_bytes: 50} }

        before do
          2.times { subject.consumed(message) }
        end

        context "and messages_pending > threshold_messages" do
          let(:threshold_messages) { 1 }

          it "returns false" do
            expect(subject.depleting?).to eq(true)
          end
        end

        context "and messages_pending = threshold_messages" do
          let(:threshold_messages) { 2 }

          it "returns true" do
            expect(subject.depleting?).to eq(true)
          end
        end

        context "and messages_pending < threshold_messages" do
          let(:threshold_messages) { 3 }

          it "returns true" do
            expect(subject.depleting?).to eq(true)
          end
        end
      end
    end
  end

  describe "#refill" do
    before { subject.consumed(message) }

    context "when max_messages is set" do
      let(:params) { {max_messages: 100} }

      it "adds max_messages to messages_pending" do
        subject.refill

        expect(subject.messages_pending).to eq(199)
      end

      it "does not change bytes_pending" do
        subject.refill

        expect(subject.bytes_pending).to eq(nil)
      end
    end

    context "when max_bytes is set" do
      let(:params) { {max_bytes: 100} }

      it "adds max_messages to messages_pending" do
        subject.refill

        expect(subject.messages_pending).to eq(1_999_999)
      end

      it "adds max_bytes to bytes_pending" do
        subject.refill

        expect(subject.bytes_pending).to eq(184)
      end
    end
  end

  describe "#trim" do
    let(:trim) { subject.trim(message) }

    let(:message) do
      NATS::JetStream::BatchCompletedMessage.new(
        consumer,
        NATS::Msg.new(
          subject: "subject",
          header: {
            "Nats-Pending-Messages" => nats_pending_messages,
            "Nats-Pending-Bytes" => nats_pending_bytes
          },
          data: "data",
          reply: "inbox"
        )
      )
    end

    let(:nats_pending_messages) { 5 }
    let(:nats_pending_bytes) { 5 }

    context "when max_messages is set" do
      let(:params) { {max_messages: 100} }

      context "when Nats-Pending-Messages < messages_pending" do
        let(:nats_pending_messages) { 5 }

        it "substracts Nats-Pending-Messages from messages_pending" do
          trim

          expect(subject.messages_pending).to eq(95)
        end

        it "does not change bytes_pending" do
          trim

          expect(subject.bytes_pending).to eq(nil)
        end
      end

      context "when Nats-Pending-Messages >= messages_pending" do
        let(:nats_pending_messages) { 105 }

        it "sets messages_pending to 0" do
          trim

          expect(subject.messages_pending).to eq(0)
        end

        it "does not change bytes_pending" do
          trim

          expect(subject.bytes_pending).to eq(nil)
        end
      end
    end

    context "when max_bytes is set" do
      let(:params) { {max_bytes: 100} }

      context "when Nats-Pending-Messages < messages_pending" do
        let(:nats_pending_messages) { 5 }

        it "substracts Nats-Pending-Messages from messages_pending" do
          trim

          expect(subject.messages_pending).to eq(999_995)
        end
      end

      context "when Nats-Pending-Messages >= messages_pending" do
        let(:nats_pending_messages) { 1_000_005 }

        it "sets messages_pending to 0" do
          trim

          expect(subject.messages_pending).to eq(0)
        end
      end

      context "when Nats-Pending-Bytes < bytes_pending" do
        let(:nats_pending_bytes) { 5 }

        it "substracts Nats-Pending-Bytes from bytes_pending" do
          trim

          expect(subject.bytes_pending).to eq(95)
        end
      end

      context "when Nats-Pending-Bytes >= bytes_pending" do
        let(:nats_pending_bytes) { 105 }

        it "sets bytes_pending to 0" do
          trim

          expect(subject.bytes_pending).to eq(0)
        end
      end
    end
  end
end
