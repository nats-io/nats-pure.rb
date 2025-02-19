# frozen_string_literal: true

module NATS
  class JetStream
    class Consumer
      class Limits < NATS::Utils::Config
        # The maximum amount of Memory storage Stream Messages may consume
        integer :max_memory

        # The maximum amount of File storage Stream Messages may consume
        integer :max_storage

        # The maximum number of Streams an account can create
        integer :max_streams

        # The maximum number of Consumer an account can create
        integer :max_consumers

        # Indicates if Streams created in this account requires the max_bytes property set
        bool :max_bytes_required

        # The maximum number of outstanding ACKs any consumer may configur
        integer :max_ack_pending

        # The maximum size any single memory stream may be
        integer  :memory_max_stream_bytes, default: -1

        # The maximum size any single storage based stream may be
        integer :storage_max_stream_bytes, default: -1
      end

      class SequenceInfo < NATS::Utils::Config
        # The sequence number of the Consumer
        integer :consumer_seq

        # The sequence number of the Stream
        integer :stream_seq

        # The last time a message was delivered or acknowledged (for ack_floor)
        string :last_active
      end
    end
  end
end
