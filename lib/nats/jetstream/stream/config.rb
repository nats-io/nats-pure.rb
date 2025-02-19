# frozen_string_literal: true

module NATS
  class JetStream
    class Stream
      # Subject transform to apply to matching messages going into the stream
      class SubjectTransform < NATS::Utils::Config
        # The subject transform sourc
        string :src, required: true

        # The subject transform destinatio
        string :dst, required: true
      end

      class StreamSource < NATS::Utils::Config
        string :name, required: true
        integer :opt_start_seq
        integer :opt_start_time
        string :filter_subject

        object :external, of: ExternalStream
        array :subject_transforms, of: SubjectTransform

        string :domain
      end

      class StreamSourceInfo < NATS::Utils::Config
        # The name of the Stream being replicate
        string :name

        # The subject filter to apply to the message
        string :filter_subject

        # The subject filtering sources and associated destination transforms
        # Subject transform to apply to matching messages going into the stream
        array :subject_transforms, of: SubjectTransform

        # How many messages behind the mirror operation is
        integer :lag, min: 0, max: 18446744073709551615

        # When last the mirror had activity, in nanoseconds. Value will be -1 when there has been no activity.
        integer :active, min: -1, max: 9223372036854775807

        # Configuration referencing a stream source in another account or JetStream domain
        object :external, of: ExternalStream

        object :error, as: ErrorResponse
      end

      # Configuration referencing a stream source in another 
      # account or JetStream domain
      class ExternalStream < NATS::Utils::Config
        # The subject prefix that imports the other account/domain 
        # $JS.API.CONSUMER.> subject
        string :api

        # The delivery subject to use for the push consume
        string :deliver
      end

      class Config < NATS::Utils::Config
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
