# frozen_string_literal: true

RSpec.describe NATS::Object::Watcher::Options do
  subject { described_class.new(options) }

  describe "#initialize" do
    let(:options) do
      {
        ignore_deletes: false,
        include_history: false,
        updates_only: false
      }
    end

    it "sets attributes" do
      expect(subject).to have_attributes(
        ignore_deletes: false,
        include_history: false,
        updates_only: false
      )
    end
  end

  describe "#consume" do
    context "when :include_history = false" do
      context "and :updates_only = false" do
        let(:options) { {include_history: false, updates_only: false} }

        it "returns consume options" do
          expect(subject.consume).to eq(deliver_policy: :last_per_subject)
        end
      end

      context "and :updates_only = true" do
        let(:options) { {include_history: false, updates_only: true} }

        it "returns consume options" do
          expect(subject.consume).to eq(deliver_policy: :new)
        end
      end
    end

    context "when :include_history = true" do
      context "and :updates_only = false" do
        let(:options) { {include_history: true, updates_only: false} }

        it "returns consume options" do
          expect(subject.consume).to eq(deliver_policy: nil)
        end
      end

      context "and :updates_only = true" do
        let(:options) { {include_history: true, updates_only: true} }

        it "returns consume options" do
          expect(subject.consume).to eq(deliver_policy: :new)
        end
      end
    end
  end
end
