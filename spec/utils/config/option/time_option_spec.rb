# frozen_string_literal: true

RSpec.describe NATS::Utils::Config::TimeOption do
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

    context "when value is time" do
      let(:raw_value) { Time.new(2025, 1, 1, 15, 0, 0) }

      it "returns itself" do
        expect(value).to eq(Time.new(2025, 1, 1, 15, 0, 0))
      end
    end

    context "when value is a date" do
      let(:raw_value) { Date.new(2025, 1, 1) }

      it "typecasts date to time" do
        expect(value).to eq(Time.new(2025, 1, 1))
      end
    end

    context "when value is a string containing valid date" do
      let(:raw_value) { "2025-01-01 15:00:00" }

      it "parses the string" do
        expect(value).to eq(Time.new(2025, 1, 1, 15, 0, 0))
      end
    end

    context "when value is a string containing invalid date" do
      let(:raw_value) { "invalid" }

      it "raises DateError" do
        expect { value }.to raise_error(ArgumentError)
      end
    end

    context "when value can not be typecasted to date" do
      let(:raw_value) { 5 }

      it "raises TimeError" do
        expect { value }.to raise_error(NATS::Utils::Config::TimeError)
      end
    end
  end

  describe "#to_h" do
    let(:to_h) { subject.to_h(Time.new(2025, 1, 1)) }

    it "returns itself" do
      expect(to_h).to eq(Time.new(2025, 1, 1))
    end
  end
end
