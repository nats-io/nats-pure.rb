# frozen_string_literal: true

RSpec.describe NATS::Object::Put::ChunksInfo do
  subject { described_class.new }

  describe "#size" do
    it "returns size" do
      expect(subject.size).to eq(0)
    end
  end

  describe "#chunks" do
    it "returns chunks" do
      expect(subject.chunks).to eq(0)
    end
  end

  describe "#digest" do
    it "returns digest" do
      expect(subject.digest).to start_with("SHA-256=")
    end
  end

  describe "#to_hash" do
    it "returns chunks as hash" do
      expect(subject.to_hash).to match(
        size: 0,
        chunks: 0,
        digest: start_with("SHA-256=")
      )
    end
  end

  describe "#published" do
    let(:published) { subject.published("chunk") }

    it "increases size" do
      published
      expect(subject.size).to eq(5)
    end

    it "increases chunks" do
      published
      expect(subject.chunks).to eq(1)
    end

    it "updates digest" do
      digest = subject.digest
      published

      expect(subject.digest).to start_with("SHA-256=")
      expect(subject.digest).to_not eq(digest)
    end
  end
end
