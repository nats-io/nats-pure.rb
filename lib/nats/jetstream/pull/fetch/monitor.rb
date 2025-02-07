# frozen_string_literal: true

module NATS
  class JetStream
    class Fetch < Pull
      class Monitor < Pull::Monitor
        attr_reader :timeout

        def initialize(pull)
          super

          @timeout = Concurrent::ScheduledTask.new(config.expires_seconds + 1) do
            handle_timeout
          end
        end

        def start
          timeout.execute
          heartbeats.execute
        end

        def stop
          timeout.cancel
          heartbeats.cancel
        end

        private

        def handle_no_heartbeats
          synchronize do
            pull.error("No Heartbeats")
            pull.drain
          end
        end

        def handle_timeout
          synchronize do
            pull.error("Request Timeout")
            pull.drain
          end
        end
      end
    end
  end
end
