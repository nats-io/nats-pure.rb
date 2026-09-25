# frozen_string_literal: true

describe NATS::Subscription do
  describe "#enqueue_processing" do
    subject(:sub) do
      described_class.new.tap do |s|
        s.callback = proc {}
        s.pending_queue = Queue.new
      end
    end

    let(:executor) { Concurrent::ImmediateExecutor.new }

    it "keeps the concurrency permit count intact when the queue is empty" do
      sub.enqueue_processing(executor)

      expect(sub.concurrency_semaphore.available_permits).to eq(1)
    end
  end
end
