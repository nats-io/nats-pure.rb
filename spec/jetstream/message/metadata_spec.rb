# frozen_string_literal: true

RSpec.describe NATS::JetStream::Message::Metadata do
  subject { described_class.new(reply) }

  context "with V1 reply" do
    let(:reply) { "$JS.ACK.stream.consumer.3.2795.3495.1744033099995368000.7" }

    it "parses V1 metadata" do
      expect(subject).to have_attributes(
        stream: "stream",
        consumer: "consumer",
        domain: nil,
        sequence: have_attributes(stream: 2795, consumer: 3495),
        num_delivered: 3,
        num_pending: 7,
        timestamp: 1744033099995368000
      )
    end
  end

  context "with V2 reply" do
    context "and 11 tokens" do
      let(:reply) { "$JS.ACK.domain.account.stream.consumer.3.2795.3495.1744033099995368000.7" }

      it "parses V2 metadata" do
        expect(subject).to have_attributes(
          stream: "stream",
          consumer: "consumer",
          domain: "domain",
          sequence: have_attributes(stream: 2795, consumer: 3495),
          num_delivered: 3,
          num_pending: 7,
          timestamp: 1744033099995368000
        )
      end
    end

    context "and 12 tokens" do
      let(:reply) { "$JS.ACK.domain.account.stream.consumer.3.2795.3495.1744033099995368000.7.random" }

      it "parses V2 metadata" do
        expect(subject).to have_attributes(
          stream: "stream",
          consumer: "consumer",
          domain: "domain",
          sequence: have_attributes(stream: 2795, consumer: 3495),
          num_delivered: 3,
          num_pending: 7,
          timestamp: 1744033099995368000
        )
      end
    end
  end

  context "with a random reply" do
    let(:reply) { "random.reply" }

    it "raises NotJsMessageError" do
      expect { subject }.to raise_error(NATS::JetStream::NotJsMessageError)
    end
  end

  context "with an emoty reply" do
    let(:reply) {}

    it "raises NotJsMessageError" do
      expect { subject }.to raise_error(NATS::JetStream::NotJsMessageError)
    end
  end
end
