# frozen_string_literal: true

module NATS
  class Stress
    class JetStream < Stress
      class FetchTest < Test
        private

        def _run
          messages = consumer.fetch(params)

          logger.info("Fetched #{messages.count} messages")
        end

        def operation
          "fetch"
        end
      end
    end
  end
end
