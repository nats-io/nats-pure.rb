# frozen_string_literal: true

module NATS
  class JetStream
    class Stream 
      class Info < NATS::Utils::Config
        object :config, of: Config

        # Detail about the current State of the Stream
        object :state, of: State

        # Timestamp when the stream was created
        string :created

        # The server time the stream info was created
        string :ts

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
            bool :current, default: false

            # Nanoseconds since this peer was last seen
            integer :number

            # Indicates the node is considered offline by the group
            bool :offline, default: false

            # How many uncommitted operations this peer is behind the leader
            integer :lag, min: 0
          end
        end


        # Information about an upstream stream source in a mirror
        object :mirror, of: StreamSourceInfo

        # Streams being sourced into this Stream
        # Information about an upstream stream source in a mirror
        # the same as mirror
        array :sources, of: StreamSourceInfo

        # List of mirrors sorted by priority
        # An alternate location to read mirrored data
        array :alternatives do
          # The mirror stream nam
          string :name
          # The name of the cluster holding the strea
          string :cluster
          # The domain holding the strin
          string :domain
        end
      end
    end
  end
end
