# frozen_string_literal: true

module NATS
  class JetStream
    class Consume < Pull
      class Handler < Pull::Handler
        def consumer(message)
          synchronize do
            heartbeats.reset
          end

          block.call(message)

          synchronize do
            buffer.consumed(message)
            refill_messages if buffer.depleting?
          end
        end

        def heartbeat(message)
          synchronize do
            heartbeats.reset
          end
        end

        def warning(message)
          synchronize do
            heartbeats.reset

            buffer.trim(message) if message.pull_terminated?
            refill_messages if buffer.depleting?
          end
        end

        def error(message)
          synchronize do
            pull.drain(message.to_error)
          end
        end

        private

        def refill_messages
          pull.request_messages
          buffer.refill
        end
      end
    end
  end
end
