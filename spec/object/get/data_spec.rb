# frozen_string_literal: true

RSpec.describe NATS::Object::Get::Data do
  subject { described_class.new(info, NATS::Object::Get::Options.new(options)) }

  let(:info) do
    NATS::Object::Info.new(
      name: "object",
      digest: "SHA-256=Om6weQ85rIfJTzhWst0sXREOaBFgImGpqSPTuyOtyLc="
    )
  end

  let(:options) { {as: :string, timeout: 1} }

  describe "#io" do
    it "returns io specified by options" do
      expect(subject.io).to be_a(StringIO)
    end
  end

  describe "#digest" do
    it "returns digest" do
      expect(subject.digest).to be_a(String)
    end
  end

  describe "#<<" do
    let(:write) { subject << "chunk" }

    it "writes chunk to io" do
      write
      subject.io.rewind

      expect(subject.io.read).to eq("chunk")
    end

    it "updates digest" do
      digest = subject.digest
      write

      expect(subject.digest).to_not eq(digest)
    end
  end

  describe "#close" do
    context "without error" do
      it "closes io" do
        subject.close

        expect(subject.io.closed?).to be(true)
      end

      it "does not set an error" do
        subject.close

        expect(subject.error).to be(nil)
      end
    end

    context "with error" do
      let(:close) { subject.close("error") }

      it "closes io" do
        close

        expect(subject.io.closed?).to be(true)
      end

      it "sets an error" do
        close

        expect(subject.error).to be("error")
      end
    end
  end

  describe "#wait" do
    def write_and_close
      Thread.new do
        3.times do
          sleep 0.1
          subject << "data"
        end

        subject.close
      end
    end

    it "waits until io is closed" do
      write_and_close
      subject.wait(1)

      expect(subject.io.closed?).to be(true)
    end
  end

  describe "#valid?" do
    context "when digest is the same as info.digest" do
      before { subject << "data" }

      it "returns true" do
        expect(subject.valid?).to be(true)
      end
    end

    context "when digest differs from info.digest" do
      before { subject << "chunk" }

      it "returns false" do
        expect(subject.valid?).to be(false)
      end
    end
  end

  describe "#data" do
    before { subject << "data" }

    context "with options[:as] = :string" do
      it "returns data as string" do
        expect(subject.data).to eq("data")
      end
    end

    context "with options[:as] != :string" do
      let(:options) { {as: :file, timeout: 1} }

      it "returns data as IO" do
        expect(subject.data).to be_a(Tempfile)
      end
    end
  end
end
