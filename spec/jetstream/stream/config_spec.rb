# frozen_string_literal: true

RSpec.describe NATS::JetStream::Stream::Config do
  subject { described_class.new(config) }

  describe "#initialize" do
    let(:config) do
      {
        name: "stream",
        description: "description",
        subjects: ["subject"],
        storage: "file",
        num_replicas: 3,
        max_age: 70,
        max_bytes: 100,
        max_msgs: 50,
        max_msg_size: 30,
        max_consumers: 5,
        max_msgs_per_subject: 5,
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
        mirror: mirror,
        sources: [source],
        republish: {
          source: "source",
          destination: "destination",
          headers_only: false
        },
        subject_transform: subject_transform,
        consumer_limits: {
          inactive_threshold: 100,
          max_ack_pending: 7
        }
      }
    end

    let(:mirror) do
      {
        name: "mirror",
        filter_subject: "mirror",
        opt_start_seq: 1,
        opt_start_time: 100,
        external: external,
        subject_transforms: [subject_transform],
        domain: "domain"
      }
    end

    let(:source) do
      {
        name: "source",
        opt_start_seq: 5,
        opt_start_time: 200,
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
      expect(subject).to to_have_attributes(config)
    end
  end
end
