# frozen_string_literal: true

RSpec.describe NATS::JetStream::Consumer::Config do
  subject { described_class.new(config) }

  describe "#initialize" do
    let(:config) do
      {
        name: "consumer",
        durable_name: "durable_name",
        description: "description",
        deliver_policy: "last",
        ack_policy: "none",
        ack_wait: 5,
        max_deliver: 10,
        filter_subject: "consumer",
        filter_subjects: ["consumer"],
        replay_policy: "original",
        sample_freq: "frequency",
        rate_limit_bps: 100,
        max_ack_pending: 4,
        idle_heartbeat: 500,
        flow_control: false,
        max_waiting: 50,
        direct: false,
        headers_only: true,
        max_batch: 5,
        max_expires: 3,
        max_bytes: 100,
        inactive_threshold: 70,
        backoff: [10, 20, 30],
        num_replicas: 4,
        mem_storage: true,
        # metadata: { key: :value },
        opt_start_seq: 1,
        opt_start_time: Time.parse("2025-01-01")
      }
    end

    it "sets attributes" do
      expect(subject).to be_config(config)
    end
  end
end
