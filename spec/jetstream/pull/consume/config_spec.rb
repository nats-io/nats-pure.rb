# frozen_string_literal: true

require_relative "../config_examples"

RSpec.describe NATS::JetStream::Consume::Config do
  subject { described_class.new(values) }

  let(:values) { {} }

  include_examples "NATS::JetStream::Pull::Config"

  context "#max_messages" do
    context "when max_messages is specified" do
      context "and max_bytes is specified" do
        let(:values) { {max_messages: 50, max_bytes: 50} }

        it "sets max_messages to the specified value" do
          expect(subject.max_messages).to eq(50)
        end
      end

      context "and max_bytes is not specified" do
        let(:values) { {max_messages: 50} }

        it "sets max_messages to the specified value" do
          expect(subject.max_messages).to eq(50)
        end
      end

      context "and max_messages < 1" do
        let(:values) { {max_messages: 0} }

        it "raises MinError" do
          expect { subject }.to raise_error(NATS::Utils::Config::MinError)
        end
      end
    end

    context "when max_messages is not specified" do
      context "and max_bytes is specified" do
        let(:values) { {max_bytes: 50} }

        it "sets max_messages to 1_000_000" do
          expect(subject.max_messages).to eq(1_000_000)
        end
      end

      context "and max_bytes is not specified" do
        it "sets max_messages to 100" do
          expect(subject.max_messages).to eq(100)
        end
      end
    end
  end

  context "#max_bytes" do
    context "when max_bytes is specified" do
      context "and max_messages is specified" do
        let(:values) { {max_messages: 50, max_bytes: 50} }

        it "sets max_bytes to nil" do
          expect(subject.max_bytes).to eq(nil)
        end
      end

      context "and max_messages is not specified" do
        let(:values) { {max_bytes: 50} }

        it "sets max_bytes to the specified value" do
          expect(subject.max_bytes).to eq(50)
        end
      end

      context "and max_bytes < 0" do
        let(:values) { {max_bytes: -1} }

        it "raises MinError" do
          expect { subject }.to raise_error(NATS::Utils::Config::MinError)
        end
      end
    end

    context "when max_bytes is not specified" do
      context "and max_messages is specified" do
        let(:values) { {max_messages: 50} }

        it "sets max_bytes to nil" do
          expect(subject.max_bytes).to eq(nil)
        end
      end

      context "and max_messages is not specified" do
        it "sets max_bytes to nill" do
          expect(subject.max_bytes).to eq(nil)
        end
      end
    end
  end

  describe "#threshold_messages" do
    context "when threshold_messages < half of max_messages" do
      let(:values) { {max_messages: 100, threshold_messages: 25} }

      it "sets threshold_messages to the specified value" do
        expect(subject.threshold_messages).to eq(25)
      end
    end

    context "when threshold_messages < 1" do
      let(:values) { {threshold_messages: 0} }

      it "raises MinError" do
        expect { subject }.to raise_error(NATS::Utils::Config::MinError)
      end
    end

    context "when threshold_messages > half of max_messages" do
      let(:values) { {max_messages: 100, threshold_messages: 70} }

      it "raises InvalidThresholdError" do
        expect { subject }.to raise_error(NATS::JetStream::InvalidThresholdError)
      end
    end

    context "when threshold_messages is not specified" do
      let(:values) { {max_messages: 50} }

      it "sets threshold_messages to half of max_message" do
        expect(subject.threshold_messages).to eq(25)
      end
    end
  end

  describe "#threshold_bytes" do
    context "when max_bytes is nil" do
      let(:values) { {max_messages: 100} }

      it "sets threshold_bytes to nil" do
        expect(subject.threshold_bytes).to eq(nil)
      end
    end

    context "when threshold_bytes < half of max_bytes" do
      let(:values) { {max_bytes: 100, threshold_bytes: 25} }

      it "sets threshold_bytes to the specified value" do
        expect(subject.threshold_bytes).to eq(25)
      end
    end

    context "when threshold_bytes < 1" do
      let(:values) { {threshold_bytes: -1} }

      it "raises MinError" do
        expect { subject }.to raise_error(NATS::Utils::Config::MinError)
      end
    end

    context "when threshold_bytes > half of max_bytes" do
      let(:values) { {max_bytes: 100, threshold_bytes: 70} }

      it "raises InvalidThresholdError" do
        expect { subject }.to raise_error(NATS::JetStream::InvalidThresholdError)
      end
    end

    context "when threshold_bytes is not specified" do
      let(:values) { {max_bytes: 50} }

      it "sets threshold_bytes to half of max_message" do
        expect(subject.threshold_bytes).to eq(25)
      end
    end
  end
end
