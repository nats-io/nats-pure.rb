# frozen_string_literal: true

module NATS
  class JetStream
    class Stream
      class Config < Config
        option :name, type: :string, validate: :name
        option :storage, type: :string, validate: :storage
        option :subjects, type: :string, validate: { in: %i[file storage] }, editable: true
        option :replicas, type: :int, editable: true, validate: { max: 5 }

        option :max_age, type: :int, editable: true
        option :max_bytes, type: :int, editable: true
        option :max_msgs, type: :int, editable: true
        option :max_msg_size, type: :int, editable: true

        option :max_consumers, type: :int

        option :no_ack, type: :bool, default: false
        option :retention, type: :string, default: :limits, validate: { in: %i[limits work_queue interest] }

        option :discard, type: :string, defalut: :old, editable: true, validate: { in: %i[old new] }

        option :duplicate_window, type: :integer, editable: true

        option :placement, editable: true do
          option :cluster
          option :tags
        end

        option :mirror, type: :string
        option :sources, type: :array, editable: true

        option :max_msgs_per_subject, type: :int, editable: true
        option :description, type: :string, editable: true
        option :sealed, type: :bool

        option :deny_delete, type: :bool
        option :deny_purge, type: :bool

        option :allow_rollup, type: :bool, editable: true

        option :re_publish, editable: true do
          option :source, type: :string
          option :destination, type: :string
          option :headers_only, type: :bool
        end

        option :allow_direct, type: :bool, editable: true
        option :mirror_direct, type: :bool, editable: true
        option :discard_new_per_subject, type: :bool, editable: true

        option :metadata, type: :hash, editable: true
        option :compression, type: :string, editable: true

        option :first_seq, type: :string
        option :subject_transform, editable: true do
          option :source, type: :string
          option :destination, type: :string
        end

        option :consumer_limits, type: :int, editable: true
      end
    end
  end
end
