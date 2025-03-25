# frozen_string_literal: true

module NATS
  class JetStream
    class Fetch < Pull
      class Handler < Pull::Handler
        def consumer(message)
          synchronize do
            heartbeats.reset
            buffer.fetched(message)

            pull.drain if buffer.full?
          end
        end

        def heartbeat(message)
          synchronize do
            heartbeats.reset
          end
        end

        def warning(message)
          synchronize do
            pull.drain(message.to_error)
          end
        end

        def error(message)
          synchronize do
            pull.drain(message.to_error)
          end
        end
      end
    end
  end
end
