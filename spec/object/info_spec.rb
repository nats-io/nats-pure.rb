# frozen_string_literal: true

RSpec.describe NATS::Object::Info do
  subject { described_class.new(meta) }

  let(:meta) do
    {
      name: "object",
      description: "description",
      headers: {"Header" => "Value"},
      metadata: {key: "value"},
      options: options,
      bucket: "bucket",
      nuid: "nuid",
      mtime: mtime,
      size: size,
      chunks: 5,
      digest: digest,
      deleted: false,
      message: message
    }
  end

  let(:size) { 500 }
  let(:digest) { "SHA-256=ZGlnZXN0" }
  let(:mtime) {}
  let(:message) {}

  let(:options) do
    {
      link: {
        bucket: "bucket",
        name: "name"
      },
      max_chunk_size: 256 * 1024
    }
  end

  describe "#initialize" do
    it "sets attributes" do
      expect(subject).to have_attributes(
        name: "object",
        description: "description",
        headers: {"Header" => "Value"},
        metadata: {key: "value"},
        options: have_attributes(
          link: have_attributes(
            bucket: "bucket",
            name: "name"
          ),
          max_chunk_size: 256 * 1024
        ),
        bucket: "bucket",
        nuid: "nuid",
        size: 500,
        chunks: 5,
        digest: "SHA-256=ZGlnZXN0",
        deleted: false
      )
    end
  end

  describe "#mtime" do
    context "when mtime is specified" do
      let(:mtime) { Time.parse("2025-05-01 15:00") }

      it "sets mtime to the specified value" do
        expect(subject.mtime).to eq(Time.parse("2025-05-01 15:00"))
      end
    end

    context "when message is specified" do
      let(:message) do
        NATS::JetStream::Message.new(
          double(NATS::JetStream::Consumer, stream: double(js: nil)),
          NATS::Msg.new(reply: "$JS.ACK.stream.consumer.3.2795.3495.1746097200.7")
        )
      end

      it "sets mtime to message.time" do
        expect(subject.mtime).to eq(Time.at(1746097200))
      end
    end

    context "when neither mtime nor message is specified" do
      it "sets time to the current time" do
        expect(subject.mtime.to_i).to be_within(Time.now.to_i).of(1)
      end
    end
  end

  describe "#link" do
    context "when object is a link" do
      it "returns options.link" do
        expect(subject.link).to have_attributes(
          bucket: "bucket",
          name: "name"
        )
      end
    end

    context "when object is not a link" do
      let(:options) { nil }

      it "returns nil" do
        expect(subject.link).to be(nil)
      end
    end
  end

  describe "#link?" do
    context "when object is a link" do
      it "returns true" do
        expect(subject.link?).to be(true)
      end
    end

    context "when object is not a link" do
      let(:options) { nil }

      it "returns false" do
        expect(subject.link?).to be(false)
      end
    end
  end

  describe "no_data?" do
    context "when size is zero" do
      let(:size) { 0 }

      it "returns true" do
        expect(subject.no_data?).to be(true)
      end
    end

    context "when size > zero" do
      it "returns false" do
        expect(subject.no_data?).to be(false)
      end
    end
  end

  describe "#raw_digest" do
    context "when digest is valid" do
      it "decodes Base64 digest hash" do
        expect(subject.raw_digest).to eq("digest")
      end
    end

    context "when digest is invalid" do
      let(:digest) { "SHA-256-digest" }

      it "raises InvalidDigestError" do
        expect { subject.raw_digest }.to raise_error(NATS::Object::InvalidDigestError)
      end
    end
  end
end
