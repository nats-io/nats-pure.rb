# frozen_string_literal: true

RSpec.describe NATS::Utils::List do
  subject { described_class.new(parent) }

  let(:parent) { "parent" }

  describe "#parent" do
    it "returns parent" do
      expect(subject.parent).to eq(parent)
    end
  end

  describe "#each" do
    let(:each) do
      items = []

      subject.each do |item|
        items << items
      end

      items
    end

    context "when there are no items in the list" do
      it "does not do anything" do
        # expect(each).to eq([])
      end

      it "returns list" do
        # expect(each).to eq(subject)
      end
    end

    context "when there are items in the list" do
      before do
        3.times do |index|
          subject.insert(index)
        end
      end

      it "iterates over the list items" do
        # expect(each).to eq([0, 1, 2])
      end

      it "returns list" do
        # expect(each).to eq(subject)
      end
    end
  end

  describe "#insert" do
    before do
      3.times do |index|
        subject.insert(index)
      end
    end

    let(:insert) { subject.insert(3) }

    context "when list does not contain the item" do
      it "adds the item to the list" do
        insert

        expect(subject.to_a).to match([0, 1, 2, 3])
      end
    end

    context "when list already contains the item" do
      before { subject.insert(3) }

      it "does not add the item to the list" do
        insert

        expect(subject.to_a).to match([0, 1, 2, 3])
      end
    end
  end
end
