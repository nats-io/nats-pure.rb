# frozen_string_literal: true

module NATS
  class JetStream
    class API
      class ConsumerCreateRequest < Request
        schema do
          # The name of the stream to create the consumer in
          string :stream_name

          object :config, of: Consumer::Config

          # The consumer create action
          string :action, in: ["create", "update", ""]
        end
      end

      class ConsumerListRequest < Request
        schema do
          integer :offset, min: 0
        end
      end

      class ConsumerNamesRequest < Request
        schema do
          integer :offset, min: 0

          # Filter the names to those consuming messages matching 
          # this subject or wildcar
          string :subject
        end
      end

      class ConsumerGetNextRequest < Request
        schema do
          # A duration from now when the pull should expire,
          # stated in nanoseconds, 0 for no expiry
          integer :expires

          # How many messages the server should deliver to the requestor
          integer :batch

          # Sends at most this many bytes to the requestor,
          # limited by consumer configuration max_bytes
          integer :max_bytes

          # When true a response with a 404 status header 
          # will be returned when no messages are available
          bool :no_wait

          # When not 0 idle heartbeats will be sent on this interval
          integer :idle_heartbeat
        end
      end
    end
  end
end
