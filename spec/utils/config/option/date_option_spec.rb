# frozen_string_literal: true

RSpec.describe NATS::Utils::Config::DateOption do
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

    context "when value is a date" do
      let(:raw_value) { Date.new(2025, 1, 1) }

      it "returns itself" do
        expect(value).to eq(Date.new(2025, 1, 1))
      end
    end

    context "when value is time" do
      let(:raw_value) { Time.new(2025, 1, 1, 15, 0, 0) }

      it "typecasts time to date" do
        expect(value).to eq(Date.new(2025, 1, 1))
      end
    end

    context "when value is a string containing valid date" do
      let(:raw_value) { "2025-01-01" }

      it "parses the string" do
        expect(value).to eq(Date.new(2025, 1, 1))
      end
    end

    context "when value is a string containing invalid date" do
      let(:raw_value) { "invalid" }

      it "raises DateError" do
        expect { value }.to raise_error(Date::Error)
      end
    end

    context "when value can not be typecasted to date" do
      let(:raw_value) { 5 }

      it "raises DateError" do
        expect { value }.to raise_error(NATS::Utils::Config::DateError)
      end
    end
  end

  describe "#to_h" do
    let(:to_h) { subject.to_h(Date.new(2025, 1, 1)) }

    it "returns itself" do
      expect(to_h).to eq(Date.new(2025, 1, 1))
    end
  end
end
