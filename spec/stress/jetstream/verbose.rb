# frozen_string_literal: true

module NATS
  class Stress
    class JetStream < Stress
      module Verbose
        class << self
          def on
            NATS::JetStream::Pull.prepend(Pull)

            NATS::JetStream::Fetch::Handler.prepend(Handler)
            NATS::JetStream::Fetch::Heartbeats.prepend(Heartbeats)
            NATS::JetStream::Fetch::Timeout.prepend(Timeout)

            NATS::JetStream::Consume::Handler.prepend(Handler)
            NATS::JetStream::Consume::Heartbeats.prepend(Heartbeats)
            NATS::JetStream::Consume::Connection.prepend(Connection)
          end
        end

        module Pull
          attr_reader :logger

          def initialize(consumer, params = {}, &block)
            super(consumer, params)
            @logger = params[:logger]
          end

          def request_messages
            logger.info("Requesting messages #{buffer.inspect} (status #{js.client.status})")
            super
          end

          def drain(error = nil)
            if error
              logger.error("Draining due to #{error.inspect}")
            else
              logger.info("Draining pull")
            end

            super
          end

          def closed!
            logger.info("Pull closed")
            super
          end
        end

        module Handler
          def heartbeat(message)
            pull.logger.info("Heartbeat #{message.inspect}")
            super
          end

          def warning(message)
            pull.logger.warn("Warning #{message.inspect}")
            super
          end

          def error(message)
            pull.logger.error("Error #{message.inspect}")
            super
          end
        end

        module Heartbeats
          def handle
            pull.logger.info("No Heartbeat")
            super
          end
        end

        module Timeout
          def task
            @task ||= Concurrent::ScheduledTask.new(timeout) do
              pull.logger.info("Timeout")
              pull.synchronize do
                pull.drain(PullTimeoutError.new)
              end
            end
          end
        end

        module Connection
          def close
            pull.logger.info("Connection Closed")
            super
          end

          def disconnect
            pull.logger.info("Disconnected")
            super
          end

          def connect
            pull.logger.info("Reconnected")
            super
          end
        end
      end
    end
  end
end
