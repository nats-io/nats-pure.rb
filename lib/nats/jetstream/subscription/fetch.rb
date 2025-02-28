# frozen_string_literal: true

module NATS
  class JetStream
    class Subscription
      class Fetch < Pull
        include Enumerable

        def each(&block)
          @handler = block
          execute
          # wait on cond before return
          self
        end

        private

        def handle_message(message)
          synchronize do
            heartbeats.reset

            messages.fetched(message)
            drain if messages.full?
          end

          handler.call(message)
        end

        def handle_heartbeat(message)
          synchronize do
            heartbeats.reset
          end
        end

        def handle_termintation(message)
          synchronize do
            error(message)
            drain
          end
        end

        def handle_error(message)
          synchronize do
            error(message)
            drain
          end
        end

        def handle_heartbeats_error
          synchronize do
            #error()
            drain
          end
        end
      end
    end
  end
end
