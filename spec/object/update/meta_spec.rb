# frozen_string_literal: true

RSpec.describe NATS::Object::Update::Meta do
  subject { described_class.new(object, meta) }

  let(:object) { NATS::Object.new(nil, info) }
  let(:info) do
    NATS::Object::Info.new(
      name: "object",
      description: "description",
      headers: {"Header" => "Value"},
      metadata: {key: "value"}
    )
  end

  describe "#initialize" do
    context "when meta options" do
      let(:meta) do
        {
          name: "other",
          description: "other description",
          headers: {"Nats-Rollup" => "sub"},
          metadata: {size: 0}
        }
      end

      it "sets attributes" do
        expect(subject).to have_attributes(
          name: "other",
          description: "other description",
          headers: {"Nats-Rollup" => "sub"},
          metadata: {size: 0}
        )
      end
    end

    context "when some meta options are nil" do
      let(:meta) { {name: "other"} }

      it "sets default values from object" do
        expect(subject).to have_attributes(
          name: "other",
          description: "description",
          headers: {"Header" => "Value"},
          metadata: {key: "value"}
        )
      end
    end
  end

  describe "#changed?" do
    let(:changed) { subject.changed?(:name) }

    context "when set value nil" do
      let(:meta) { {description: "desc"} }

      it "returns false" do
        expect(changed).to be(false)
      end
    end

    context "when set value differs from object value" do
      let(:meta) { {name: "other"} }

      it "returns true" do
        expect(changed).to be(true)
      end
    end

    context "when set value does not differ from object value" do
      let(:meta) { {name: "object"} }

      it "returns false" do
        expect(changed).to be(false)
      end
    end
  end
end
