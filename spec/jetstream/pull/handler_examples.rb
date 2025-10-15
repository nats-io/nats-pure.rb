# frozen_string_literal: true

RSpec.shared_examples "NATS::JetStream::Handler" do
  describe "draining" do
    let(:handle) { subject.handle(message) }
    let(:header) { {"Status" => "100"} }

    before do
      allow(pull.subscription).to receive(:empty?).and_return(empty)
    end

    context "when pull is processing" do
      before { pull.send(:processing!) }

      context "and there are messages left" do
        let(:empty) { false }

        it "does not close pull" do
          handle

          expect(pull.closed?).to be(false)
        end
      end

      context "and processing the last message" do
        let(:empty) { true }

        it "does not close pull" do
          handle

          expect(pull.closed?).to be(false)
        end
      end
    end

    context "when pull is draining" do
      before { pull.send(:draining!) }

      context "and there are messages left" do
        let(:empty) { false }

        it "does not close pull" do
          handle

          expect(pull.closed?).to be(false)
        end
      end

      context "and processing the last message" do
        let(:empty) { true }

        it "closes pull" do
          handle

          expect(pull.closed?).to be(true)
        end
      end

      context "and processing the last message raises an error" do
        let(:empty) { true }
        let(:header) { {} }
        let(:block) { ->(message) { raise StandarError } }

        it "closes pull" do
          begin
            handle
          rescue
            nil
          end

          expect(pull.closed?).to be(true)
        end
      end
    end
  end
end
