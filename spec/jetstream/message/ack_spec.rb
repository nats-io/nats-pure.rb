# frozen_string_literal: true

RSpec.describe NATS::JetStream::Message::Ack do
  subject { described_class.new(message) }

  let(:consumer) { NATS::JetStream::Consumer.new(stream, name: "consumer") }
  let(:stream) { NATS::JetStream::Stream.new(js, name: "stream") }

  let(:js) { NATS::JetStream::Context.new(client) }
  let(:client) { double(NATS::Client, request: nil) }

  let(:message) do
    NATS::JetStream::Message.new(
      consumer,
      NATS::Msg.new(
        subject: "subject",
        raw_header: "header",
        data: "data",
        reply: "$JS.ACK.stream.consumer.3.2795.3495.1744.7"
      )
    )
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
    let(:ack) { subject.ack(params) }

    context "when message has been acked" do
      let(:params) { {} }

      before { subject.ack }

      it "raise MessageAckedError" do
        expect { ack }.to raise_error(NATS::JetStream::MessageAckedError)
      end
    end

    context "without params" do
      let(:params) { {} }

      it "acks message" do
        ack

        expect(client).to have_received(:request).with(
          "$JS.ACK.stream.consumer.3.2795.3495.1744.7",
          "+ACK"
        )
      end
    end

    context "with :timeout param" do
      let(:params) { {timeout: 0.5} }

      it "sets timeout for the ack request" do
        ack

        expect(client).to have_received(:request).with(
          "$JS.ACK.stream.consumer.3.2795.3495.1744.7",
          "+ACK",
          timeout: 0.5
        )
      end
    end
  end

  describe "#nack" do
    let(:nack) { subject.nack(params) }

    context "when message has been acked" do
      let(:params) { {} }

      before { subject.nack }

      it "raise MessageAckedError" do
        expect { nack }.to raise_error(NATS::JetStream::MessageAckedError)
      end
    end

    context "without params" do
      let(:params) { {} }

      it "nacks message" do
        nack

        expect(client).to have_received(:request).with(
          "$JS.ACK.stream.consumer.3.2795.3495.1744.7",
          "-NACK"
        )
      end
    end

    context "with :delay param" do
      let(:params) { {delay: 0.5} }

      it "sets delay for the nack request" do
        nack

        expect(client).to have_received(:request).with(
          "$JS.ACK.stream.consumer.3.2795.3495.1744.7",
          "-NACK {\"delay\":0.5}",
          delay: 0.5
        )
      end
    end

    context "with :timeout param" do
      let(:params) { {timeout: 0.5} }

      it "sets timeout for the nack request" do
        nack

        expect(client).to have_received(:request).with(
          "$JS.ACK.stream.consumer.3.2795.3495.1744.7",
          "-NACK",
          timeout: 0.5
        )
      end
    end
  end

  describe "#term" do
    let(:term) { subject.term(params) }

    context "when message has been acked" do
      let(:params) { {} }

      before { subject.term }

      it "raise MessageAckedError" do
        expect { term }.to raise_error(NATS::JetStream::MessageAckedError)
      end
    end

    context "without params" do
      let(:params) { {} }

      it "terms message" do
        term

        expect(client).to have_received(:request).with(
          "$JS.ACK.stream.consumer.3.2795.3495.1744.7",
          "+TERM"
        )
      end
    end

    context "with :reason param" do
      let(:params) { {reason: "reason"} }

      it "sets reason for the term request" do
        term

        expect(client).to have_received(:request).with(
          "$JS.ACK.stream.consumer.3.2795.3495.1744.7",
          "+TERM reason",
          reason: "reason"
        )
      end
    end

    context "with :timeout param" do
      let(:params) { {timeout: 0.5} }

      it "sets timeout for the term request" do
        term

        expect(client).to have_received(:request).with(
          "$JS.ACK.stream.consumer.3.2795.3495.1744.7",
          "+TERM",
          timeout: 0.5
        )
      end
    end
  end

  describe "#in_progress" do
    let(:in_progress) { subject.in_progress(params) }

    context "without params" do
      let(:params) { {} }

      it "marks message as in progress" do
        in_progress

        expect(client).to have_received(:request).with(
          "$JS.ACK.stream.consumer.3.2795.3495.1744.7",
          "+WPI"
        )
      end
    end

    context "with :timeout param" do
      let(:params) { {timeout: 0.5} }

      it "sets timeout for the in progress request" do
        in_progress

        expect(client).to have_received(:request).with(
          "$JS.ACK.stream.consumer.3.2795.3495.1744.7",
          "+WPI",
          timeout: 0.5
        )
      end
    end
  end
end
