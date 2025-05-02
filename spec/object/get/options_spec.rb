# frozen_string_literal: true

RSpec.describe NATS::Object::Get::Options do
  subject { described_class.new(options) }

  describe "#initialize" do
    let(:options) do
      {
        show_deleted: true,
        as: :file,
        path: "path/to/file",
        async: true,
        timeout: 5
      }
    end

    it "sets attributes" do
      expect(subject).to have_attributes(
        show_deleted: true,
        as: :file,
        path: "path/to/file",
        async: true,
        timeout: 5
      )
    end
  end

  describe "#io" do
    context "when :as = :string" do
      let(:options) { {as: :string} }

      it "returns StringIo" do
        expect(subject.io).to be_a(StringIO)
      end
    end

    context "when :as = :file" do
      context "and path is specified" do
        let(:options) { {as: :file, path: path} }
        let(:path) { "#{FileUtils.pwd}/tmp/file.txt" }

        after do
          subject.io.close
          FileUtils.rm(path)
        end

        it "returns File" do
          expect(subject.io).to be_a(File)
          expect(subject.io.path).to eq(path)
        end
      end

      context "and path is not specified" do
        let(:options) { {as: :file} }

        after { subject.io.unlink }

        it "returns Tempfile" do
          expect(subject.io).to be_a(Tempfile)
        end
      end
    end

    context "when :as is an object" do
      let(:options) { {as: StringIO.new} }

      it "returns the object" do
        expect(subject.io).to be_a(StringIO)
      end
    end

    context "when :as is nil" do
      let(:options) { {as: nil} }

      after { subject.io.unlink }

      it "returns Tempfile" do
        expect(subject.io).to be_a(Tempfile)
      end
    end
  end

  describe "#wait?" do
    context "when :async = true" do
      let(:options) { {async: true} }

      it "returns false" do
        expect(subject.wait?).to be(false)
      end
    end

    context "when :async = false" do
      let(:options) { {async: false} }

      it "returns true" do
        expect(subject.wait?).to be(true)
      end
    end
  end

  describe "#as_string?" do
    context "when :as = :string" do
      let(:options) { {as: :string} }

      it "returns true" do
        expect(subject.as_string?).to be(true)
      end
    end

    context "when :as is not string" do
      let(:options) { {as: :file} }

      it "returns false" do
        expect(subject.as_string?).to be(false)
      end
    end
  end

  describe "#as_string?" do
    context "when :as is nil" do
      let(:options) { {as: nil} }

      it "returns true" do
        expect(subject.lazy?).to be(true)
      end
    end

    context "when :as is present" do
      let(:options) { {as: :string} }

      it "returns false" do
        expect(subject.lazy?).to be(false)
      end
    end
  end
end
