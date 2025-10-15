# frozen_string_literal: true

module NATS
  class Stress
    class JetStream < Stress
      class Test < Stress::Test
        def run
          logger.info("==> Running #{context[:type]} with #{context[:params]}...")

          publisher.start if context[:publish]

          _run

          publisher.stop if context[:publish]

          client.close
        end

        def info
          "#{context[:stream]} with #{context[:params]}"
        end

        def logfile
          "#{operation}/#{context[:stream]}-#{context[:type]}"
        end

        private

        def js
          @js ||= client.js
        end

        def client
          @client ||=
            if context[:server]
              NATS.connect(context[:server])
            else
              NATS.connect
            end
        end

        def stream
          @stream ||= js.streams.find(context[:stream])
        end

        def consumer
          @consumer ||= stream.consumers.upsert(
            name: "#{operation}-#{context[:stream]}-#{SecureRandom.hex(5)}"
          )
        end

        def params
          @params ||= context[:params].merge(logger: logger)
        end

        def publisher
          @publisher ||= Publisher.new(stream, logger)
        end
      end
    end
  end
end

require_relative "test/fetch"
require_relative "test/consume"
require_relative "test/long"
