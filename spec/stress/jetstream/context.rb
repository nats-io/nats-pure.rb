# frozen_string_literal: true

module NATS
  class Stress
    class JetStream < Stress
      class Context
        def materialize(options = {})
          product(options).map do |stream, params|
            {**stream, **params}
          end
        end

        private

        def product(options)
          streams(options).product(params)
        end

        def streams(options)
          streams = self.class::STREAMS
          streams = streams.slice(*options[:stream]) if options[:stream]

          streams.map do |name, stream|
            stream.new.context
          end
        end
      end

      class FetchContext < Context
        STREAMS = {
          small_stream: SmallStream,
          large_stream: LargeStream,
          large_messages: LargeMessages,
          continuous: Continuous,
          mixed: Mixed
        }

        def params
          @params ||= FetchParams.new.to_a
        end
      end

      class ConsumeContext < Context
        STREAMS = {
          small_stream: SmallStream,
          large_stream: LargeStream,
          large_messages: LargeMessages,
          continuous: Continuous,
          mixed: Mixed,
          connection: Connection
        }

        def params
          @params ||= ConsumeParams.new.to_a
        end
      end

      class LongContext < Context
        STREAMS = {
          continuous: Continuous,
          connection: Connection
        }

        def params
          [{}]
        end
      end
    end
  end
end
