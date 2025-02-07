# frozen_string_literal: true

module NATS
  class JetStream
    class Consume
      class Monitor < Pull::Monitor
        attr_reader :connection, :status_listener

        def initialize(pull)
          super

          @status_listener = client.status_listeners.create
        end

        def start
          heartbeats.execute
          start_connection
        end

        def stop
          heartbeats.cancel
          status_listener.close
          connection.exit
        end

        private

        def handle_no_heartbeats
          synchronize { reset_request }
        end

        def reset_request
          pull.request_messages
          pull.buffer.reset

          reset_heartbeats
        end

        def reset_heartbeats
          heartbeats.cancel
          set_heartbeats
          heartbeats.execute
        end

        def start_connection
          @connection = Thread.new do
            connected = true

            loop do
              status = status_listener.pop

              synchronize do
                if connected && status.reconnecting?
                  heartbeats.cancel
                  connected = false
                end

                if !connected && status.connected?
                  reset_request
                  connected = true
                end
              end
            end
          end

          @connection.name = "nats::js::consume::#{object_id}"
        end

        def client
          pull.js.client
        end
      end
    end
  end
end
