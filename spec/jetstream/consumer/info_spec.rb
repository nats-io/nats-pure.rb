# frozen_string_literal: true

RSpec.describe NATS::JetStream::Consumer::Info do
  before(:all) do
    @server = NatsServerControl.new(
      "nats://127.0.0.1:4222",
      "/tmp/test-nats.pid",
      "-js"
    )
    @server.start_server(true)
  end

  after(:all) do
    @server.kill_server
  end

  describe "#initialize" do
    subject { described_class.new(info) }

    let(:info) do
      {
        stream_name: "stream",
        name: "consumer",
        ts: Time.parse("2025-01-01 15:00"),
        config: config,
        created: Time.parse("2025-01-01 17:00"),
        delivered: delivered,
        ack_floor: ack_floor,
        num_ack_pending: 5,
        num_redelivered: 4,
        num_waiting: 3,
        num_pending: 7,
        cluster: {
          name: "cluster",
          leader: "leader",
          replicas: [
            {
              current: false,
              active: 500,
              offline: false,
              lag: 100
            }
          ]
        },
        push_bound: false
      }
    end

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
        opt_start_time: Time.parse("2025-01-01 15:00")
      }
    end

    let(:delivered) do
      {
        consumer_seq: 3,
        stream_seq: 4,
        last_active: Time.parse("2025-01-01 15:00")
      }
    end

    let(:ack_floor) do
      {
        consumer_seq: 5,
        stream_seq: 7,
        last_active: Time.parse("2025-01-01 15:00")
      }
    end

    it "sets attributes" do
      expect(subject).to be_config(info)
    end
  end

  describe "server response" do
    subject { consumer.info }

    let(:consumer) { stream.consumers.upsert(name: "consumer") }
    let(:stream) { js.streams.create(name: "stream") }
    let(:js) { NATS.connect.js }

    after do
      consumer.delete
      stream.delete
    end

    it "returns info" do
      expect(subject).to have_attributes(
        stream_name: "stream",
        name: "consumer",
        ts: be_a(Time),
        created: be_a(Time),
        config: have_attributes(
          name: "consumer",
          durable_name: nil,
          description: nil,
          deliver_policy: "all",
          ack_policy: "explicit",
          ack_wait: 30000000000,
          max_deliver: -1,
          filter_subject: nil,
          filter_subjects: nil,
          replay_policy: "instant",
          sample_freq: nil,
          rate_limit_bps: nil,
          max_ack_pending: -1,
          idle_heartbeat: nil,
          flow_control: nil,
          max_waiting: 512,
          direct: nil,
          headers_only: false,
          max_batch: nil,
          max_expires: 0,
          max_bytes: nil,
          inactive_threshold: 5000000000,
          backoff: nil,
          num_replicas: 0,
          mem_storage: false,
          metadata: be_a(Hash).or(be(nil)),
          opt_start_seq: nil,
          opt_start_time: nil
        ),
        delivered: have_attributes(
          consumer_seq: be_a(Integer),
          stream_seq: be_a(Integer),
          last_active: nil
        ),
        ack_floor: have_attributes(
          consumer_seq: be_a(Integer),
          stream_seq: be_a(Integer),
          last_active: nil
        ),
        num_ack_pending: be_a(Integer),
        num_redelivered: be_a(Integer),
        num_waiting: be_a(Integer),
        num_pending: be_a(Integer),
        cluster: nil,
        push_bound: nil
      )
    end
  end
end
