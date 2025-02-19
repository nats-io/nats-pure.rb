# frozen_string_literal: true

module NATS
  class JetStream
    class Stream
      class Config < NATS::Utils::Config
        # Name is an optional name for the consumer. If not set, one is
        # generated automatically.
        string :name, as: :name

        # Durable is an optional durable name for the consumer. If both Durable
        # and Name are set, they have to be equal. Unless InactiveThreshold is set, a
        # durable consumer will not be cleaned up automatically.
        string :durable_name, as: :name

        # Description provides an optional description of the consumer.
        string :description

        # DeliverPolicy defines from which point to start delivering messages
        # from the stream. Defaults to DeliverAllPolicy.
        string :deliver_policy, in: %w[all last last_per_subject new by_start_sequence by_start_time], default: "all"

        # OptStartSeq is an optional sequence number from which to start
        # message delivery. Only applicable when DeliverPolicy is set to
        # DeliverByStartSequencePolicy.
        string :opt_start_seq
        # OptStartTime is an optional time from which to start message
        # delivery. Only applicable when DeliverPolicy is set to
        # DeliverByStartTimePolicy.
        integer :opt_start_time

        # AckPolicy defines the acknowledgement policy for the consumer.
        # Defaults to AckExplicitPolicy.
        string :ack_policy, in: %w[explicit none all], default: "explicit"

        # AckWait defines how long the server will wait for an acknowledgement
        # before resending a message. If not set, server default is 30 seconds.
        integer :ack_wait

        # MaxDeliver defines the maximum number of delivery attempts for a
        # message. Applies to any message that is re-sent due to ack policy.
        # If not set, server default is -1 (unlimited).
        integer :max_deliver, default: -1

        # BackOff specifies the optional back-off intervals for retrying
        # message delivery after a failed acknowledgement. It overrides
        # AckWait.
        #
        # BackOff only applies to messages not acknowledged in specified time,
        # not messages that were nack'ed.
        #
        # The number of intervals specified must be lower or equal to
        # MaxDeliver. If the number of intervals is lower, the last interval is
        # used for all remaining attempts.
        integer :backoff

        # FilterSubject can be used to filter messages delivered from the
        # stream. FilterSubject is exclusive with FilterSubjects.
        string :filter_subject

        # ReplayPolicy defines the rate at which messages are sent to the
        # consumer. If ReplayOriginalPolicy is set, messages are sent in the
        # same intervals in which they were stored on stream. This can be used
        # e.g. to simulate production traffic in development environments. If
        # ReplayInstantPolicy is set, messages are sent as fast as possible.
        # Defaults to ReplayInstantPolicy.
        string :replay_policy, in: %w[original instant], default: "instant"

        # RateLimit specifies an optional maximum rate of message delivery in
        # bits per second.
        integer :ate_limit_bps

        # SampleFrequency is an optional frequency for sampling how often
        # acknowledgements are sampled for observability. See
        # https://docs.nats.io/running-a-nats-service/nats_admin/monitoring/monitoring_jetstream
        string :sample_frequency

        # MaxWaiting is a maximum number of pull requests waiting to be
        # fulfilled. If not set, this will inherit settings from stream's
        # ConsumerLimits or (if those are not set) from account settings.  If
        # neither are set, server default is 512.
        integer :max_waiting

        # MaxAckPending is a maximum number of outstanding unacknowledged
        # messages. Once this limit is reached, the server will suspend sending
        # messages to the consumer. If not set, server default is 1000.
        # Set to -1 for unlimited.
        integer :max_ack_pending, default: -1

        # HeadersOnly indicates whether only headers of messages should be sent
        # (and no payload). Defaults to false.
        bool :headers_only

        # MaxRequestBatch is the optional maximum batch size a single pull
        # request can make. When set with MaxRequestMaxBytes, the batch size
        # will be constrained by whichever limit is hit first.
        integer :max_batch

        # MaxRequestExpires is the maximum duration a single pull request will
        # wait for messages to be available to pull.
        integer :max_expires

        # MaxRequestMaxBytes is the optional maximum total bytes that can be
        # requested in a given batch. When set with MaxRequestBatch, the batch
        # size will be constrained by whichever limit is hit first.
        integer :max_bytes

        # InactiveThreshold is a duration which instructs the server to clean
        # up the consumer if it has been inactive for the specified duration.
        # Durable consumers will not be cleaned up by default, but if
        # InactiveThreshold is set, they will be. If not set, this will inherit
        # settings from stream's ConsumerLimits. If neither are set, server
        # default is 5 seconds.
        #
        # A consumer is considered inactive there are not pull requests
        # received by the server (for pull consumers), or no interest detected
        # on deliver subject (for push consumers), not if there are no
        # messages to be delivered.
        integer :inactive_threashold

        # Replicas the number of replicas for the consumer's state. By default,
        # consumers inherit the number of replicas from the stream.
        integer :num_replicas

        # MemoryStorage is a flag to force the consumer to use memory storage
        # rather than inherit the storage type from the stream.
        bool :memory_storage

        # FilterSubjects allows filtering messages from a stream by subject.
        # This field is exclusive with FilterSubject. Requires nats-server
        # v2.10.0 or later.
        array :filter_subjects, of: :string

        # Metadata is a set of application-defined key-value pairs for
        # associating metadata on the consumer. This feature requires
        # nats-server v2.10.0 or later.
        hash :metadata
      end
    end
  end
end
