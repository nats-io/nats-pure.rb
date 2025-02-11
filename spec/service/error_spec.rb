# frozen_string_literal: true

RSpec.describe NATS::Service::ErrorWrapper do
  subject { described_class.new(error) }

  let(:error) { {code: 503, description: "error"} }

  describe "#description" do
    it "combines code with message" do
      expect(subject.description).to eq("503:error")
    end
  end

  context "when error is a string" do
    let(:error) { "error" }

    it "builds an error from the string" do
      expect(subject).to have_attributes(code: 500, message: "error", data: "")
    end
  end

  context "when error is a hash" do
    let(:error) { {code: 503, description: "error", data: "data"} }

    it "builds an error from the hash" do
      expect(subject).to have_attributes(code: 503, message: "error", data: "data")
    end
  end

  context "when error is of Exception" do
    let(:error) { StandardError.new("error") }

    it "builds an error from the error" do
      expect(subject).to have_attributes(code: 500, message: "error", data: "")
    end
  end

  context "when error is of ErrorWrapper" do
    let(:error) { described_class.new("error") }

    it "builds an error from the wrapper" do
      expect(subject).to have_attributes(code: 500, message: "error", data: "")
    end
  end

  context "when error is a random object" do
    let(:error) { [1, 2, 3] }

    it "builds an error from the object" do
      expect(subject).to have_attributes(code: 500, message: "[1, 2, 3]", data: "")
    end
  end
end
