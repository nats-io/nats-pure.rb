# frozen_string_literal: true

RSpec.describe NATS::JetStream::Api do
  subject { NATS::JetStream::Api.new(jetstream, prefix) }

  let(:jetstream) { NATS::JetStream::Context.new(client) }
  let(:client) { double(NATS::Client) }
  let(:prefix) { nil }

  describe "#subject" do
    context "when prefix is not set" do
      it "returns default prefix" do
        expect(subject.subject).to eq("$JS.API")
      end
    end

    context "when prefix is set" do
      let(:prefix) { "$PREFIX.API" }

      it "returns the specified prefix" do
        expect(subject.subject).to eq("$PREFIX.API")
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
