# frozen_string_literal: true

module NATS
  class Stress
    class JetStream < Stress
      class Publisher
        attr_reader :js, :stream, :logger

        def initialize(stream, logger)
          @js = stream.js
          @stream = stream
          @logger = logger
        end

        def start
          @thread = Thread.new do
            logger.info("Publishing messages...")

            loop do
              sleep sleep_time

              count = messages_count

              count.times do |index|
                js.publish(stream.subject, Random.bytes(rand * 1_00))
              end

              logger.info("=> Published #{count} messages")
            end
          end
        end

        def stop
          @thread.exit
        end

        private

        def sleep_time
          rand * 10
        end

        def messages_count
          (rand * 10).to_i
        end
      end
    end
  end
end
