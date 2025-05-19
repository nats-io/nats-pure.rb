# frozen_string_literal: true

RSpec.describe NATS::Utils::Config::BoolOption do
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

    context "when value is true" do
      let(:raw_value) { true }

      it "returns true" do
        expect(value).to eq(true)
      end
    end

    context "when value is 1" do
      let(:raw_value) { 1 }

      it "returns true" do
        expect(value).to eq(true)
      end
    end

    context "when value is t" do
      let(:raw_value) { "t" }

      it "returns true" do
        expect(value).to eq(true)
      end
    end

    context "when value is other than 1, t or true" do
      let(:raw_value) { "value" }

      it "returns false" do
        expect(value).to eq(false)
      end
    end

    context "when params[:default] is set" do
      let(:params) { {default: true} }

      context "when value is nil" do
        let(:raw_value) { nil }

        it "returns default value" do
          expect(value).to eq(true)
        end
      end

      context "when values is not nil" do
        let(:raw_value) { false }

        it "returns value" do
          expect(value).to eq(false)
        end
      end
    end
  end

  describe "#to_h" do
    let(:to_h) { subject.to_h(true) }

    it "returns itself" do
      expect(to_h).to eq(true)
    end
  end
end
