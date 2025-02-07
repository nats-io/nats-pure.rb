# frozen_string_literal: true

RSpec.describe NATS::Utils::List do
  describe "#to_nsec" do
    let(:to_nsec) { number.to_nsec }

    context "when number is integer" do
      let(:number) { 5 }

      it "returns nanoseconds" do
        expect(to_nsec).to eq(5_000_000_000)
      end
    end

    context "when number is float" do
      let(:number) { 0.5 }

      it "returns nanoseconds" do
        expect(to_nsec).to eq(500_000_000)
      end
    end
  end

  describe "#from_nsec" do
    let(:from_nsec) { number.from_nsec }

    it "returns seconds" do
      expect(5_000_000_000.from_nsec).to eq(5)
    end

    context "when number is integer" do
      let(:number) { 5000 }

      it "returns nanoseconds" do
        expect(from_nsec).to eq(0.000_005)
      end
    end

    context "when number is float" do
      let(:number) { 500.5 }

      it "returns nanoseconds" do
        expect(from_nsec).to eq(0.000_000_500_5)
      end
    end
  end
end
