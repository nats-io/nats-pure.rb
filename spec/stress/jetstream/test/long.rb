# frozen_string_literal: true

module NATS
  class Stress
    class JetStream < Stress
      class LongTest < ConsumeTest
        def initialize(context)
          @context = context

          @logdev = $stdout
          @logger = ::Logger.new(@logdev)
        end

        private

        def _run
          lock = Monitor.new
          count = 0

          consume = consumer.consume(logger: logger) do |message|
            lock.synchronize do
              count += 1
              logger.info("Consumed #{count} messages") if count % 1_000 == 0
            end
            message.ack
          end

          sleep 3_600
          consume.drain

          logger.info("Count: #{count}")
        end

        def operation
          "long-consume"
        end
      end
    end
  end
end
