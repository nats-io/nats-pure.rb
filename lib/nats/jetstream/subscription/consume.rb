# frozen_string_literal: true

module NATS
  class JetStream
    class Subscription
      class Consume < Pull
        def handle_message(message)
          synchronize do
            heartbeats.reset

            messages.consumed(message)
            request_messages if messages.threashold?
          end

          handler.call(message)
        end

        def handle_heartbeat(message)
          synchronize do
            heartbeats.reset
          end
        end

        def handle_warning(message)
        end

        def handle_error(message)
        end

        def handle_no_heartbeats
        end
      end
    end
  end
end
