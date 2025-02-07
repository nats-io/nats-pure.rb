# frozen_string_literal: true

module NATS
  class JetStream
    class Stream
      class Config < NATS::Utils::Config
        # A unique name for the Stream, empty for Stream Templates
        string :name, as: :name, required: true

        # A short description of the purpose of this stream
        string :description

        # A list of subjects to consume, supports wildcards.
        # Must be empty when a mirror is configured.
        # May be empty when sources are configured
        array :subjects, of: :string

        # The storage backend to use for the Stream
        string :storage, in: %w[file memory], default: "file"

        # How many replicas to keep for each message
        integer :num_replicas, max: 5, default: 1

        # Maximum age of any message in the stream, expressed
        # in nanoseconds. 0 for unlimited
        integer :max_age

        # How big the Stream may be, when the combined stream
        # size exceeds this old messages are removed. -1 for unlimited
        integer :max_bytes, default: -1

        # How many messages may be in a Stream, oldest messages will
        # be removed if the Stream exceeds this size. -1 for unlimited
        integer :max_msgs, default: -1

        # The largest message that will be accepted by the Stream.
        # -1 for unlimited
        integer :max_msg_size, default: -1

        # How many Consumers can be defined for a given Stream.
        # -1 for unlimited
        integer :max_consumers

        # For wildcard streams ensure that for every unique subject
        # this many messages are kept - a per subject retention limit
        integer :max_msgs_per_subject, default: -1

        # Disables acknowledging messages that are received by the Stream
        bool :no_ack, default: false

        # How messages are retained in the Stream, once this is
        # exceeded old messages are removed
        string :retention, in: %w[limits work_queue interest], default: "limits"

        # When a Stream reach it's limits either old messages are
        # deleted or new ones are denied
        string :discard, in: %w[old new], default: "old"

        # When discard policy is new and the stream is one with
        # max messages per subject set, this will apply the new
        # behavior to every subject. Essentially turning discard
        # new from maximum number of subjects into maximum number
        # of messages in a subject
        bool :discard_new_per_subject, default: false

        # The time window to track duplicate messages for,
        # expressed in nanoseconds. 0 for default
        integer :duplicate_window, default: 0

        # Placement directives to consider when placing replicas
        # of this stream, random placement when unset
        object :placement do
          # The desired cluster name to place the stream
          string :cluster

          # Tags required on servers hosting this stream"
          array :tags, of: :string
        end

        # Maintains a 1:1 mirror of another stream with name
        # matching this property. When a mirror is configured
        # subjects and sources must be empty
        object :mirror, of: StreamSource

        # List of Stream names to replicate into this Stream
        array :sources, of: StreamSource

        # Sealed streams do not allow messages to be deleted via
        # limits or API, sealed streams can not be unsealed via
        # configuration update. Can only be set on already created
        # streams via the Update API
        bool :sealed, default: false

        # Restricts the ability to delete messages from a stream
        # via the API. Cannot be changed once set to true
        bool :deny_delete, default: false

        # Restricts the ability to purge messages from a stream via
        # the API. Cannot be change once set to true
        bool :deny_purge, default: false

        # Allows the use of the Nats-Rollup header to replace all contents
        # of a stream, or subject in a stream, with a single new message
        bool :allow_rollup, default: false

        # Rules for republishing messages from a stream with subject
        # mapping onto new subjects for partitioning and more"
        object :republish do
          # The source subject to republish
          string :source

          # The destination to publish to
          string :destination, required: true

          # Only send message headers, no bodies
          bool :headers_only
        end

        # Subject transform to apply to matching messages
        object :subject_transform, of: SubjectTransform

        # Allow higher performance, direct access to get individual messages
        bool :allow_direct, default: false

        # Allow higher performance, direct access for mirrors as well
        bool :mirror_direct, default: false

        # Optional compression algorithm used for the Stream
        string :compression, in: %w[none s2], default: "none"

        # A custom sequence to use for the first message in the stream
        string :first_seq

        # Limits of certain values that consumers can set, defaults
        # for those who don't set these settings
        object :consumer_limits do
          # Maximum value for inactive_threshold for consumers of this
          # stream. Acts as a default when consumers do not set this value
          integer :inactive_threshold

          # Maximum value for max_ack_pending for consumers of this stream.
          # Acts as a default when consumers do not set this value
          integer :max_ack_pending
        end

        # Additional metadata for the Stream
        hash :metadata
      end
    end
  end
end
