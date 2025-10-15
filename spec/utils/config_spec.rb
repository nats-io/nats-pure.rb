# frozen_string_literal: true

RSpec.describe NATS::Utils::Config do
  let(:config) do
    Class.new(described_class) do
      integer :integer
      string :string
      bool :bool
      hash :hash

      array :array, of: :integer
      object :object do
        integer :integer
        string :string
      end
    end
  end

  subject { config.new(values) }

  let(:values) do
    {
      integer: 1,
      string: "string",
      bool: true,
      hash: {key: :value},
      array: [1, 2, 3],
      object: {integer: 2, string: "2"}
    }
  end

  describe "#initialize" do
    context "when values are nil" do
      let(:values) { {} }

      it "sets options to values" do
        expect(subject).to have_attributes(
          integer: nil,
          string: nil,
          bool: nil,
          hash: nil,
          array: nil,
          object: nil
        )
      end
    end

    context "when values are present" do
      it "sets options to values" do
        expect(subject).to have_attributes(
          integer: 1,
          string: "string",
          bool: true,
          hash: {key: :value},
          array: [1, 2, 3],
          object: have_attributes(integer: 2, string: "2")
        )
      end
    end

    context "when values are not hash-like" do
      let(:values) { :symbol }

      it "raises InvalidInputError" do
        expect { subject }.to raise_error(NATS::Utils::Config::InvalidInputError)
      end
    end
  end

  describe "#update" do
    let(:update) { subject.update(update_values) }

    context "when values are present" do
      let(:update_values) do
        {
          integer: 5,
          array: [4, 5, 7],
          object: {integer: 5, string: "5"}
        }
      end

      it "updates specified options" do
        update

        expect(subject).to have_attributes(
          integer: 5,
          string: "string",
          bool: true,
          hash: {key: :value},
          array: [4, 5, 7],
          object: have_attributes(integer: 5, string: "5")
        )
      end
    end

    context "when values are not hash-like" do
      let(:update_values) { :symbol }

      it "raises InvalidInputError" do
        expect { update }.to raise_error(NATS::Utils::Config::InvalidInputError)
      end
    end
  end

  describe "#each" do
    let(:names) do
      names = []

      subject.each do |name, value|
        names << name
      end

      names
    end

    it "iterates over all options" do
      expect(names).to eq([
        :integer, :string, :bool, :hash, :array, :object
      ])
    end
  end

  describe "#[]" do
    let(:option) { subject[name] }

    context "when option is defined" do
      let(:name) { :integer }

      it "returns option value" do
        expect(option).to eq(1)
      end
    end

    context "when option is not defined" do
      let(:name) { :non_existing }

      it "returns nil" do
        expect(option).to eq(nil)
      end
    end
  end

  describe "#to_h" do
    it "returns config as a hash" do
      expect(subject.to_h).to eq(values)
    end
  end

  describe "#to_json" do
    it "returns config as json" do
      expect(subject.to_json).to eq(values.to_json)
    end
  end
end
