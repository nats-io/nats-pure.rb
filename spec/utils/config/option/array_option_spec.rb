# frozen_string_literal: true

RSpec.describe NATS::Utils::Config::ArrayOption do
  subject { described_class.new(name, params) }

  let(:name) { :name }
  let(:params) { {item: item} }
  let(:item) { NATS::Utils::Config::IntegerOption.new(:int, {}) }

  describe "#value" do
    let(:value) { subject.value(raw_value) }

    context "when value is nil" do
      let(:raw_value) { nil }

      it "returns nil" do
        expect(value).to eq(nil)
      end
    end

    context "when value is an array" do
      let(:raw_value) { [1, 2, 3] }

      it "returns itself" do
        expect(value).to eq([1, 2, 3])
      end
    end

    context "when value can be typecasted to array" do
      let(:raw_value) { Set.new([1, 2, 3]) }

      it "typecasts value to array" do
        expect(value).to eq([1, 2, 3])
      end
    end

    context "when value can not be typecasted to array" do
      let(:raw_value) { 5 }

      it "raises ArrayError" do
        expect { value }.to raise_error(NATS::Utils::Config::ArrayError)
      end
    end

    context "when params[:item] is set" do
      let(:item) { NATS::Utils::Config::HashOption.new(:hash, {}) }
      let(:raw_value) { [[[:key, :value]]] }

      it "typecasts each item according to params[:item]" do
        expect(value).to eq([{key: :value}])
      end
    end

    context "when params[:default] is set" do
      let(:params) { {item: item, default: [1, 2, 3]} }

      context "when value is nil" do
        let(:raw_value) { nil }

        it "returns default value" do
          expect(value).to eq([1, 2, 3])
        end
      end

      context "when values is not nil" do
        let(:raw_value) { [4, 5, 6] }

        it "returns value" do
          expect(value).to eq([4, 5, 6])
        end
      end
    end
  end

  describe "#to_h" do
    let(:to_h) { subject.to_h(value) }

    context "when value is nil" do
      let(:value) { nil }

      it "returns nil" do
        expect(to_h).to eq(nil)
      end
    end

    context "when value is an array" do
      let(:config) do
        Class.new(NATS::Utils::Config) do
          integer :integer
          string :string
        end
      end

      let(:item) do
        NATS::Utils::Config::ObjectOption.new(:object, config: config)
      end

      let(:raw_value) do
        [
          {integer: 1, string: "1"},
          {integer: 2, string: "2"},
          {integer: 3, string: "3"}
        ]
      end

      let(:value) { subject.value(raw_value) }

      it "transforms value to hash" do
        expect(to_h).to eq(raw_value)
      end
    end
  end
end
