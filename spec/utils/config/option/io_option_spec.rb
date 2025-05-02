# frozen_string_literal: true

RSpec.describe NATS::Utils::Config::IoOption do
  subject { described_class.new(name, params) }

  let(:name) { :name }
  let(:params) { {} }

  describe "#value" do
    let(:value) { subject.value(raw_value) }

    context "when value is nil" do
      let(:raw_value) { nil }

      it "returns nil" do
        expect(value).to eq(nil)
      end
    end

    context "when value is of IO" do
      let(:raw_value) { File.new("tmp/file.txt", "w") }

      after { FileUtils.rm(raw_value.path) }

      it "returns itself" do
        expect(value).to eq(raw_value)
      end
    end

    context "when value is of Temfile" do
      let(:raw_value) { Tempfile.new }

      after { raw_value.unlink }

      it "returns itself" do
        expect(value).to eq(raw_value)
      end
    end

    context "when value is of StringIO" do
      let(:raw_value) { StringIO.new }

      it "returns itself" do
        expect(value).to eq(raw_value)
      end
    end

    context "when value is a string" do
      let(:raw_value) { "value" }

      it "wraps up the string with StringIO" do
        expect(value).to be_a(StringIO)
        expect(value.string).to eq("value")
      end
    end

    context "when values is not IO-like" do
      let(:raw_value) { 5 }

      it "raises IoError" do
        expect { value }.to raise_error(NATS::Utils::Config::IoError)
      end
    end
  end

  describe "#to_h" do
    let(:value) { StringIO.new("value") }
    let(:to_h) { subject.to_h(value) }

    it "returns itself" do
      expect(to_h).to eq(value)
    end
  end
end
