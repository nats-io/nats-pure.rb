# frozen_string_literal: true

RSpec.describe NATS::JetStream::API do
  subject { described_class.new(jetstream, params) }

  let(:jetstream) { NATS::JetStream::Context.new(client) }
  let(:client) { double(NATS::Client) }
  let(:params) { {} }

  describe "#subject" do
    context "when prefix is set" do
      let(:params) { {prefix: "$PREFIX.API"} }

      it "returns the specified prefix" do
        expect(subject.subject).to eq("$PREFIX.API")
      end
    end

    context "when domain is set" do
      let(:params) { {domain: "domain"} }

      it "returns the specified prefix" do
        expect(subject.subject).to eq("$JS.domain.API")
      end
    end

    context "when no parameters are provided" do
      it "returns default prefix" do
        expect(subject.subject).to eq("$JS.API")
      end
    end
  end

  describe "#js" do
    it "returns jetstream" do
      expect(subject.js).to eq(jetstream)
    end
  end

  describe "#client" do
    it "returns jetstream client" do
      expect(subject.client).to eq(client)
    end
  end
end
