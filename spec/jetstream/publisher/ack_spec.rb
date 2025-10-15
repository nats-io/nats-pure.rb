# frozen_string_literal: true

RSpec.describe NATS::JetStream::Publisher::Ack do
  describe ".build" do
    subject { described_class }

    let(:build) { subject.build(message) }
    let(:message) { NATS::Msg.new(data: data.to_json) }

    context "when a message is given" do
      let(:data) { {stream: "stream", seq: 5} }

      it "builds a response object" do
        expect(build).to be_a(subject).and be_config(data)
      end
    end

    context "when an error is given" do
      let(:data) do
        {error: {code: 404, err_code: 10059}}
      end

      it "raises ErrorResponse" do
        expect { build }.to raise_error(::NATS::JetStream::StreamNotFoundError)
      end
    end
  end

  describe "#initialize" do
    subject { described_class.new(data) }

    let(:data) do
      {
        stream: "stream",
        seq: 5,
        duplicate: false,
        domain: "domain"
      }
    end

    it "sets data" do
      expect(subject).to be_config(data)
    end
  end
end
