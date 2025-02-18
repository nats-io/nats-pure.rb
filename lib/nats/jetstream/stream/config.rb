# frozen_string_literal: true

module NATS
  class JetStream
    class Stream
      class Config < NATS::Utils::Config
        config :subject_transform do
          string :src, required: true
          string :dst, required: true
        end

        config :stream_source do
          string :name, required: true
          integer :opt_start_seq
          integer  :opt_start_time
          string :filter_subject

          object :external do
            string :api, required: true
            string :deliver
          end

          array :subject_transforms, of: :subject_transform
          string :domain
        end

        string :name, as: :name, required: true
        string :description
        array :subjects, of: :string
        #array :subjects, of: { type: :string, as: :subject }

        string :storage, in: %w[file memory], default: "file"
        integer :num_replicas, max: 5, default: 1

        integer :max_age
        integer :max_bytes, default: -1
        integer :max_msgs, default: -1
        integer :max_msg_size, default: -1
        integer :max_consumers
        integer :max_msgs_per_subject, default: -1

        # If set to true, publish methods from the JetStream client will not
        # work as expected, since they rely on acknowledgements. Core NATS
        # publish methods should be used instead. Note that this will make
        # message delivery less reliable.
        bool :no_ack, default: false
        string :retention, in: %w[limits work_queue interest], default: "limits"

        string :discard, in: %w[old new], default: "old"
        # DiscardNewPerSubject is a flag to enable discarding new messages per
        # subject when limits are reached. Requires DiscardPolicy to be
        # DiscardNew and the MaxMsgsPerSubject to be set.
        bool :discard_new_per_subject, default: false

        integer :duplicate_window, default: 0

        object :placement do
          string :cluster, required: true
          array :tags, of: :string
        end

        object :mirror, of: :stream_source
        array :sources, of: :stream_source

        bool :sealed, default: false
        bool :deny_delete, default: false
        bool :deny_purge, default: false
        bool :allow_rollup, default: false

        object :republish do
          string :source
          string :destination, required: true
          bool :headers_only
        end

        object :subject_transform, of: :subject_transform

        bool :allow_direct, default: false
        bool :mirror_direct, default: false

        string :compression, in: %w[none s2]

        string :first_seq

        object :consumer_limits do
          integer :inactive_threshold
          integer :max_ack_pending
        end

        hash :metadata
      end
    end
  end
end
