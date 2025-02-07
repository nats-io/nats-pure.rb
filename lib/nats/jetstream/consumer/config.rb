# frozen_string_literal: true

module NATS
  class JetStream
    class Stream
      class Config < Config
        option :name, type: :string, validate: :name
        option :durable, type: :string, validate: :name

        option :filter_subject, type: :string, editable: true

        option :ack_policy, type: :string, validate: { in: %i[explicit none all] }
        option :ack_wait, type: :integer, editable: true

        option :deliver_policy, type: :string, validate: { in: %i[all last last_per_subject new by_start_sequence by_start_time] }
        option :opt_start_seq, type: :string
        option :opt_start_time, type: :int

        option :description, type: :string, editable: true
        option :inactive_threashold, type: :int, editable: true

        option :max_ack_pending, type: :int, editable: true
        option :max_deliver, type: :int, editable: true
        option :backoff, type: :int, editable: true

        option :replay_policy, type: :string, validate: { in: %i[original instant] }
        option :replicas, type: :int, editable: true
        option :memory_storage, type: :bool

        option :sample_frequency, type: :int, editable: true
        option :metadata, type: :hash, editable: true
        option :filter_subjects, type: :array, editable: true
      end
    end
  end
end
