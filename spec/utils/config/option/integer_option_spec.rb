# frozen_string_literal: true

RSpec.describe NATS::Utils::Config::IntegerOption do
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

    context "when value is an integer" do
      let(:raw_value) { 5 }

      it "returns itself" do
        expect(value).to eq(5)
      end
    end

    context "when value can be typecasted to integer" do
      let(:raw_value) { "5" }

      it "typecasts value to integer" do
        expect(value).to eq(5)
      end
    end

    context "when value can not be typecasted to integer" do
      let(:raw_value) { :value }

      it "raises IntegerError" do
        expect { value }.to raise_error(NATS::Utils::Config::IntegerError)
      end
    end

    context "when params[:in] is set" do
      let(:params) { {in: (1..5)} }

      context "when value is in params[:in]" do
        let(:raw_value) { 3 }

        it "returns itself" do
          expect(value).to eq(3)
        end
      end

      context "when value is not in params[:in]" do
        let(:raw_value) { 7 }

        it "raises InclusionError" do
          expect { value }.to raise_error(NATS::Utils::Config::InclusionError)
        end
      end
    end

    context "when params[:max] is set" do
      let(:params) { {max: 5} }

      context "when value < params[:max]" do
        let(:raw_value) { 3 }

        it "returns itself" do
          expect(value).to eq(3)
        end
      end

      context "when value = params[:max]" do
        let(:raw_value) { 5 }

        it "returns itself" do
          expect(value).to eq(5)
        end
      end

      context "when value > params[:max]" do
        let(:raw_value) { 7 }

        it "raises MaxError" do
          expect { value }.to raise_error(NATS::Utils::Config::MaxError)
        end
      end
    end

    context "when params[:min] is set" do
      let(:params) { {min: 5} }

      context "when value > params[:min]" do
        let(:raw_value) { 7 }

        it "returns itself" do
          expect(value).to eq(7)
        end
      end

      context "when value = params[:min]" do
        let(:raw_value) { 5 }

        it "returns itself" do
          expect(value).to eq(5)
        end
      end

      context "when value < params[:min]" do
        let(:raw_value) { 3 }

        it "raises MinError" do
          expect { value }.to raise_error(NATS::Utils::Config::MinError)
        end
      end
    end

    context "when params[:default] is set" do
      let(:params) { {default: 5} }

      context "when value is nil" do
        let(:raw_value) { nil }

        it "returns default value" do
          expect(value).to eq(5)
        end
      end

      context "when values is not nil" do
        let(:raw_value) { 3 }

        it "returns value" do
          expect(value).to eq(3)
        end
      end
    end
  end

  describe "#to_h" do
    let(:to_h) { subject.to_h(5) }

    it "returns itself" do
      expect(to_h).to eq(5)
    end
  end
end
