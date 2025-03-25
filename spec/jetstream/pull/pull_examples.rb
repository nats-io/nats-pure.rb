# frozen_string_literal: true

RSpec.shared_examples "NATS::JetStream::Pull" do |idle_heartbeat:|
  describe "#start" do
    context "when in pending status" do
      let(:params) { {} }

      after { subject.drain }

      before do
        allow(subject.monitor).to receive(:start).and_call_original
        allow(subject.subscription).to receive(:start).and_call_original
        allow(js.api.consumer.msg).to receive(:next).and_call_original
      end

      it "moves to processing status" do
        subject.start

        expect(subject.processing?).to eq(true)
      end

      it "starts monitor" do
        subject.start

        expect(subject.monitor).to have_received(:start)
      end

      it "starts a subscription" do
        subject.start

        expect(subject.subscription).to have_received(:start)
      end

      it "requests messages" do
        subject.start

        expect(js.api.consumer.msg).to have_received(:next).with(
          "stream.consumer",
          have_attributes(
            expires: 30.to_nsec,
            idle_heartbeat: idle_heartbeat,
            max_messages: 100,
            max_bytes: nil
          ),
          reply_to: subject.subscription.inbox
        )
      end
    end

    context "when not in pending stats" do
      before do
        subject.start
        subject.drain
      end

      it "returns false" do
        expect(subject.start).to eq(false)
      end
    end
  end

  describe "#drain" do
    context "when in processing status" do
      before { subject.start }

      before do
        allow(subject.monitor).to receive(:stop).and_call_original
        allow(subject.subscription).to receive(:drain).and_call_original
      end

      it "moves to closed status" do
        subject.drain
        subject.wait(1)

        expect(subject.closed?).to eq(true)
      end

      it "stops its monitor" do
        subject.drain
        subject.wait(1)

        expect(subject.monitor).to have_received(:stop)
      end

      it "starts a subscription" do
        subject.drain
        subject.wait(1)

        expect(subject.subscription).to have_received(:drain)
      end

      context "and draining due to an error" do
        let(:error) { StandardError.new }

        it "sets the error" do
          subject.drain(error)

          expect(subject.error).to eq(error)
        end
      end
    end

    context "when not in processing status" do
      it "returns false" do
        expect(subject.drain).to eq(false)
      end

      context "and draining due to an error" do
        let(:error) { StandardError.new }

        it "does not set the error" do
          subject.drain(error)

          expect(subject.error).to be(nil)
        end
      end
    end
  end
end
