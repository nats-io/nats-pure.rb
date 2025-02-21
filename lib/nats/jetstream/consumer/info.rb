# frozen_string_literal: true

module NATS
  class JetStream
    class Consumer
      class Info < NATS::Utils::Config
        # The Stream the consumer belongs t
        string :stream_name

        # A unique name for the consumer, either machine generated or the durable nam
        string :name

        # The server time the consumer info was created
        string :ts # date-time

        object :config, of: Config

        # The time the Consumer was created
        string :created

        # The last message delivered from this Consumer
        object :delivered, of: SequenceInfo

        # The highest contiguous acknowledged message
        object :ack_floor, of: SequenceInfo

        # The number of messages pending acknowledgement
        integer :num_ack_pending

        # The number of redeliveries that have been performed
        integer :num_redelivered

        # The number of pull consumers waiting for messages
        integer :num_waiting

        # The number of messages left unconsumed in this Consumer
        integer :num_pending

        object :cluster do
          # The cluster nam
          string :name

          # The server name of the RAFT leade
          string :leader

          # The members of the RAFT cluster
          array :replicas do
            # The server name of the peer
            string :name

            # Indicates if the server is up to date and synchronised
            bool :current

            # Nanoseconds since this peer was last seen
            integer :active

            # Indicates the node is considered offline by the group
            bool :offline

            # How many uncommitted operations this peer is behind the leader
            integer :lag
          end
        end

        # Indicates if any client is connected and receiving messages from a push consumer
        bool :push_bound
      end
    end
  end
end
