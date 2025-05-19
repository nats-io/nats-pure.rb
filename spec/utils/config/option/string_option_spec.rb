# frozen_string_literal: true

RSpec.describe NATS::Utils::Config::StringOption do
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

    context "when value is a string" do
      let(:raw_value) { "value" }

      it "returns itself" do
        expect(value).to eq("value")
      end
    end

    context "when value is not a string" do
      let(:raw_value) { :value }

      it "typecasts value to string" do
        expect(value).to eq("value")
      end
    end

    context "when params[:as] is set" do
      let(:params) { {as: :name} }

      context "when value is valid" do
        let(:raw_value) { "value" }

        it "returns itself" do
          expect(value).to eq("value")
        end
      end

      context "when value is not valid" do
        let(:raw_value) { "$value.*" }

        it "raises InvalidNameError" do
          expect { value }.to raise_error(NATS::Utils::InvalidNameError)
        end
      end
    end

    context "when params[:in] is set" do
      let(:params) { {in: %w[file memory]} }

      context "when value is in params[:in]" do
        let(:raw_value) { "file" }

        it "returns itself" do
          expect(value).to eq("file")
        end
      end

      context "when value is not in params[:in]" do
        let(:raw_value) { "io" }

        it "raises InclusionError" do
          expect { value }.to raise_error(NATS::Utils::Config::InclusionError)
        end
      end
    end

    context "when params[:default] is set" do
      let(:params) { {default: "default"} }

      context "when value is nil" do
        let(:raw_value) { nil }

        it "returns default value" do
          expect(value).to eq("default")
        end
      end

      context "when values is not nil" do
        let(:raw_value) { "value" }

        it "returns value" do
          expect(value).to eq("value")
        end
      end
    end

    context "when params[:env] is set" do
      let(:params) { {env: "OPTION"} }

      before { ENV["OPTION"] = "env" }

      context "when value is nil" do
        let(:raw_value) { nil }

        it "returns env value" do
          expect(value).to eq("env")
        end
      end

      context "when values is not nil" do
        let(:raw_value) { "value" }

        it "returns value" do
          expect(value).to eq("value")
        end
      end
    end
  end

  describe "#to_h" do
    let(:to_h) { subject.to_h("value") }

    it "returns itself" do
      expect(to_h).to eq("value")
    end
  end
end
