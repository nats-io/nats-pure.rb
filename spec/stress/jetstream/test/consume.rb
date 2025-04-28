# frozen_string_literal: true

module NATS
  class Stress
    class JetStream < Stress
      class ConsumeTest < Test
        private

        def _run
          lock = Monitor.new
          count = 0

          consume = consumer.consume(params) do |message|
            lock.synchronize do
              count += 1
              logger.info("Received: #{message.inspect} (#{count})")
            end

            message.ack
          end

          sleep 30
          consume.drain

          logger.info("Consumed #{messages.count} messages")
        end

        def operation
          "consume"
        end
      end
    end
  end
end
