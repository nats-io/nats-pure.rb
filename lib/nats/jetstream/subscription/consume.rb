# frozen_string_literal: true

module NATS
  class JetStream
    class Subscription
      class Consume < Pull
        def handle_message(message)
          synchronize do
            heartbeats.reset
          end

          handler.call(message)

          synchronize do
            messages.consumed(message)

            if messages.depleting?
              messages.replenish
              request_messages 
            end
          end
        end

        def handle_heartbeat(message)
          synchronize do
            heartbeats.reset
          end
        end

        def handle_warning(message)
          synchronize do
            heartbeats.reset
          end
        end

        def handle_error(message)
          synchronize do
            error(message)
            drain
          end
        end

        def handle_no_heartbeats
        end
      end
    end
  end
end
