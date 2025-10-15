# frozen_string_literal: true

RSpec.describe NATS::Utils::Config::ObjectOption do
  subject { described_class.new(name, params) }

  let(:name) { :name }
  let(:params) { {config: config} }

  let(:config) do
    Class.new(NATS::Utils::Config) do
      integer :integer
      string :string
    end
  end

  describe "#value" do
    let(:value) { subject.value(raw_value) }

    context "when value is nil" do
      let(:raw_value) { nil }

      it "returns nil" do
        expect(value).to eq(nil)
      end
    end

    context "when value is a hash" do
      let(:raw_value) { {integer: 1, string: "1"} }

      it "returns an instance of config" do
        expect(value).to be_kind_of(config)
      end

      it "sets " do
        expect(value).to have_attributes(
          integer: 1,
          string: "1"
        )
      end
    end

    context "when value is a config" do
      let(:raw_value) { config.new(integer: 1, string: "1") }

      it "returns an instance of config" do
        expect(value).to be_kind_of(config)
      end

      it "sets " do
        expect(value).to have_attributes(
          integer: 1,
          string: "1"
        )
      end
    end

    context "when value is not hash-like" do
      let(:raw_value) { 5 }

      it "raises ObjectError" do
        expect { value }.to raise_error(NATS::Utils::Config::ObjectError)
      end
    end
  end

  describe "#to_h" do
    let(:to_h) { subject.to_h(value) }

    context "when value is nil" do
      let(:value) { nil }

      it "returns nil" do
        expect(value).to eq(nil)
      end
    end

    context "when value is a config" do
      let(:value) { config.new(integer: 1, string: "1") }

      it "transforms value to hash" do
        expect(to_h).to eq({integer: 1, string: "1"})
      end
    end
  end
end
