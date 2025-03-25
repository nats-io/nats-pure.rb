# frozen_string_literal: true

module NATS
  class JetStream
    class Consume < Pull
      class Connection
        attr_reader :pull, :thread, :status_listener

        def initialize(pull)
          @pull = pull
        end

        def start
          @connected = true

          set_listener
          set_thread
        end

        def stop
          status_listener.close
          thread.exit
        end

        private

        def set_listener
          @status_listener = pull.js.client.status_listeners.create
        end

        def set_thread
          @thread = Thread.new do
            loop do
              status = status_listener.pop

              pull.synchronize do
                close if status.closed?
                disconnect if connected? && status.reconnecting?
                connect if !connected? && status.connected?
              end
            end
          end

          @thread.name = "nats:js-consume-#{object_id}"
        end

        def connected?
          @connected
        end

        def disconnect
          pull.heartbeats.stop
          @connected = false
        end

        def connect
          pull.request_messages
          pull.buffer.reset
          pull.heartbeats.reset

          @connected = true
        end

        def close
          pull.drain
          @connected = false
        end
      end
    end
  end
end
