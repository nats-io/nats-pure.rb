# frozen_string_literal: true

RSpec.describe NATS::JetStream::Stream::Info do
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
        config: config,
        state: state,
        created: Time.parse("2025-01-01 15:00"),
        ts: Time.parse("2025-01-01 17:00"),
        cluster: {
          name: "cluster",
          leader: "leader",
          replicas: [
            {
              name: "replica",
              current: true,
              number: 100,
              offline: true,
              lag: 10
            }
          ]
        },
        mirror: info_mirror,
        sources: [info_source],
        alternatives: [
          {
            name: "alternative",
            cluster: "cluster",
            domain: "domain"
          }
        ]
      }
    end

    let(:state) do
      {
        messages: 10,
        bytes: 10,
        first_seq: 1,
        first_ts: Time.parse("2025-01-01 15:00"),
        last_seq: 10,
        last_ts: Time.parse("2025-01-01 17:00"),
        deleted: [1, 2, 3],
        # subjects: {"stream" => 10 }, #hash
        num_subjects: 1,
        num_deleted: 3,
        last: {
          msgs: [4, 5],
          bytes: 10
        },
        consumer_count: 10
      }
    end

    let(:info_mirror) do
      {
        name: "mirror",
        filter_subject: "mirror",
        subject_transforms: [subject_transform],
        lag: 1,
        active: 10,
        external: external
      }
    end

    let(:info_source) do
      {
        name: "srouce",
        filter_subject: "srouce",
        subject_transforms: [subject_transform],
        lag: 1,
        active: 10,
        external: external
      }
    end

    let(:config) do
      {
        name: "stream",
        description: "description",
        subjects: ["subject"],
        storage: "file",
        num_replicas: 3,
        max_age: 10,
        max_bytes: 10,
        max_msgs: 10,
        max_msg_size: 10,
        max_consumers: 10,
        max_msgs_per_subject: 10,
        no_ack: true,
        retention: "interest",
        discard: "new",
        discard_new_per_subject: true,
        duplicate_window: 5,
        sealed: true,
        deny_delete: true,
        deny_purge: true,
        allow_rollup: true,
        allow_direct: true,
        mirror_direct: true,
        compression: "s2",
        first_seq: "5",
        # metadata: { key: :value }, # hash
        placement: {
          cluster: "cluster",
          tags: ["tag"]
        },
        mirror: config_mirror,
        sources: [config_source],
        republish: {
          source: "source",
          destination: "destination",
          headers_only: false
        },
        subject_transform: subject_transform,
        consumer_limits: {
          inactive_threshold: 10,
          max_ack_pending: 10
        }
      }
    end

    let(:config_mirror) do
      {
        name: "mirror",
        filter_subject: "mirror",
        opt_start_seq: 1,
        opt_start_time: 10,
        external: external,
        subject_transforms: [subject_transform],
        domain: "domain"
      }
    end

    let(:config_source) do
      {
        name: "source",
        opt_start_seq: 1,
        opt_start_time: 10,
        filter_subject: "source",
        external: external,
        subject_transforms: [subject_transform],
        domain: "domain"
      }
    end

    let(:external) do
      {
        api: "api",
        deliver: "deliver"
      }
    end

    let(:subject_transform) do
      {
        src: "source",
        dst: "destination"
      }
    end

    it "sets attributes" do
      expect(subject).to be_config(info)
    end
  end

  describe "server response" do
    subject { stream.info }

    let(:stream) { js.streams.create(name: "stream") }
    let(:js) { NATS.connect.js }

    after { stream.delete }

    it "returns info" do
      expect(subject).to have_attributes(
        config: have_attributes(
          name: "stream",
          description: nil,
          subjects: ["stream"],
          storage: "file",
          num_replicas: 1,
          max_age: 0,
          max_bytes: -1,
          max_msgs: -1,
          max_msg_size: -1,
          max_consumers: -1,
          max_msgs_per_subject: -1,
          no_ack: false,
          retention: "limits",
          discard: "old",
          discard_new_per_subject: false,
          duplicate_window: 120000000000,
          placement: nil,
          mirror: nil,
          sources: nil,
          sealed: false,
          deny_delete: false,
          deny_purge: false,
          allow_rollup: false,
          republish: nil,
          subject_transform: nil,
          allow_direct: false,
          mirror_direct: false,
          compression: "none",
          first_seq: nil,
          consumer_limits: have_attributes(
            inactive_threshold: nil,
            max_ack_pending: nil
          ),
          metadata: nil
        ),
        state: have_attributes(
          messages: be_a(Integer),
          bytes: be_a(Integer),
          first_seq: be_a(Integer),
          last_seq: be_a(Integer),
          deleted: nil,
          subjects: nil,
          num_subjects: nil,
          num_deleted: nil,
          last: nil,
          consumer_count: be_a(Integer)
        ),
        created: be_a(Time),
        ts: be_a(Time),
        cluster: have_attributes(
          name: nil,
          leader: be_a(String),
          replicas: nil
        ),
        mirror: nil,
        sources: nil,
        alternatives: nil
      )
    end
  end
end
