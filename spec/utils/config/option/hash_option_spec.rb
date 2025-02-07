# frozen_string_literal: true

RSpec.describe NATS::Utils::Config::HashOption do
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

    context "when value is a hash" do
      let(:raw_value) { {key: :value} }

      it "returns itself" do
        expect(value).to eq({key: :value})
      end
    end

    context "when value can be typecasted to hash" do
      let(:raw_value) { [[:key, :value]] }

      it "typecasts value to hash" do
        expect(value).to eq({key: :value})
      end
    end

    context "when value can not be typecasted to hash" do
      let(:raw_value) { :value }

      it "raises HashError" do
        expect { value }.to raise_error(NATS::Utils::Config::HashError)
      end
    end

    context "when params[:default] is set" do
      let(:params) { {default: {key: :value}} }

      context "when value is nil" do
        let(:raw_value) { nil }

        it "returns default value" do
          expect(value).to eq({key: :value})
        end
      end

      context "when values is not nil" do
        let(:raw_value) { {value: :key} }

        it "returns value" do
          expect(value).to eq({value: :key})
        end
      end
    end
  end

  describe "#to_h" do
    let(:to_h) { subject.to_h({}) }

    it "returns itself" do
      expect(to_h).to eq({})
    end
  end
end
