# frozen_string_literal: true

module NATS
  class JetStream
    class Fetch < Pull
      class Handler < Pull::Handler
        def consumer(message)
          synchronize do
            monitor.heartbeats.reset
            buffer.fetched(message)

            pull.drain if buffer.full?
          end
        end

        def heartbeat(message)
          synchronize do
            monitor.heartbeats.reset
          end
        end

        def warning(message)
          synchronize do
            pull.error(message.description)
            pull.drain
          end
        end

        def error(message)
          synchronize do
            pull.error(message.description)
            pull.drain
          end
        end
      end
    end
  end
end
