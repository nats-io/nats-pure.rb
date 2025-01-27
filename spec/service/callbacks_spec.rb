# frozen_string_literal: true

RSpec.describe NATS::Service::Callbacks do
  subject { described_class.new(service) }

  let(:service) { instance_double(NATS::Service) }

  describe "#register" do
    let(:block) { -> { puts "callback" } }

    it "registers a callback" do
      subject.register(:stop, &block)

      expect(subject.callbacks[:stop]).to eq(block)
    end
  end

  describe "#call" do
    context "when callback is registered" do
      before do
        subject.register(:stop, &block)
      end

      context "when callback does not have arguments" do
        let(:block) { -> { 4 + 5 } }

        it "returns the result of callback execution" do
          expect(subject.call(:stop)).to eq(9)
        end
      end

      context "when callback has arguments" do
        let(:block) { ->(value) { value + 5 } }

        it "returns the result of callback execution" do
          expect(subject.call(:stop, 5)).to eq(10)
        end
      end
    end

    context "when callback is not registered" do
      it "returns nil" do
        expect(subject.call(:stop)).to be(nil)
      end
    end
  end
end
