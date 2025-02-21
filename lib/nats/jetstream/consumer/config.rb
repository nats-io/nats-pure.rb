# frozen_string_literal: true

module NATS
  class JetStream
    class Consumer
      class Config < NATS::Utils::Config
        # A unique name for a consumer
        string :name, as: :name

        # A unique name for a durable consumer
        string :durable_name, as: :name

        # A short description of the purpose of this consumer
        string :description

        # DeliverPolicy defines from which point to start delivering messages
        # from the stream. Defaults to DeliverAllPolicy.
        string :deliver_policy, in: %w[all last new by_start_sequence by_start_time last_per_subject], default: "all"

        # AckPolicy defines the acknowledgement policy for the consumer.
        # Defaults to AckExplicitPolicy.
        string :ack_policy, in: %w[none all explicit], default: "explicit"

        # How long (in nanoseconds) to allow messages to remain un-acknowledged
        # before attempting redelivery
        integer :ack_wait

        # The number of times a message will be redelivered to consumers if not acknowledged in time
        integer :max_deliver, default: -1

        # Filter the stream by a single subjects
        string :filter_subject

        # Filter the stream by multiple subjects
        array :filter_subjects, of: :string

        # ReplayPolicy defines the rate at which messages are sent to the
        # consumer. If ReplayOriginalPolicy is set, messages are sent in the
        # same intervals in which they were stored on stream. This can be used
        # e.g. to simulate production traffic in development environments. If
        # ReplayInstantPolicy is set, messages are sent as fast as possible.
        # Defaults to ReplayInstantPolicy.
        string :replay_policy, in: %w[original instant], default: "instant"

        # SampleFrequency is an optional frequency for sampling how often
        # acknowledgements are sampled for observability. See
        # https://docs.nats.io/running-a-nats-service/nats_admin/monitoring/monitoring_jetstream
        string :sample_frequency

        # The rate at which messages will be delivered to clients, expressed in 
        # bit per second
        integer :rate_limit_bps, min: 0

        # The maximum number of messages without acknowledgement that can be
        # outstanding, once this limit is reached message delivery will be suspended
        integer :max_ack_pending, default: -1

        # If the Consumer is idle for more than this many nano seconds a empty 
        # message with Status header 100 will be sent indicating the consumer 
        # is still alive
        integer :idle_heartbeat, min: 0

        # For push consumers this will regularly send an empty mess with Status 
        # header 100 and a reply subject, consumers must reply to these messages 
        # to control the rate of message deliver
        bool :flow_control

        # The number of pulls that can be outstanding on a pull consumer,
        # pulls received after this is reached are ignored
        integer :max_waiting, min: 0, default: 512

        # Creates a special consumer that does not touch the Raft layers, 
        # not for general use by clients, internal use only
        bool :direct

        # Delivers only the headers of messages in the stream and not the bodies.
        # Additionally adds Nats-Msg-Size header to indicate the size of the 
        # removed payloa
        bool :headers_only, default: false

        # The largest batch property that may be specified when doing a pull on a Pull Consumer
        integer :max_batch#, default: 0

        # The maximum expires value that may be set when doing a pull on a Pull Consumer
        integer :max_expires, default: 0

        # The maximum bytes value that maybe set when dong a pull on a Pull Consumer
        integer :max_bytes, min: 0#, deafult: 0

        # Duration that instructs the server to cleanup ephemeral consumers that are inactive for that long
        integer :inactive_threshold, default: 0

        # List of durations in Go format that represents a retry time scale for NaK'd messages
        array :backoff, of: :integer

        # When set do not inherit the replica count from the stream but specifically 
        # set it to this amount
        integer :num_replicas, min: 0, max: 5

        # Force the consumer state to be kept in memory rather than inherit the 
        # setting from the stream
        bool :mem_storage, default: false

        # Additional metadata for the Consumer
        hash :metadata

        # OptStartSeq is an optional sequence number from which to start
        # message delivery. Only applicable when DeliverPolicy is set to
        # DeliverByStartSequencePolicy.
        integer :opt_start_seq, min: 0

        # OptStartTime is an optional time from which to start message
        # delivery. Only applicable when DeliverPolicy is set to
        # DeliverByStartTimePolicy.
        string :opt_start_time # date
      end
    end
  end
end
