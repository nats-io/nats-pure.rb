# frozen_string_literal: true

module NATS
  class Stress
    class JetStream < Stress
      class Params
        include Enumerable

        def each
          self.class::TYPES.each do |type|
            send(type).each do |params|
              context = {type: type, params: params}
              yield context
            end
          end
        end

        private

        def expires
          1.upto(30).map do |expires|
            {expires: expires.to_nsec}
          end
        end

        def idle_heartbeat
          0.5.step(by: 0.5, to: 15).map do |idle_heartbeat|
            {idle_heartbeat: idle_heartbeat.to_nsec}
          end
        end

        def max_messages
          max_ranges.map do |messages|
            {max_messages: messages, expires: 10.to_nsec}
          end
        end

        def max_bytes
          max_ranges.map do |bytes|
            {max_bytes: bytes, expires: 10.to_nsec}
          end
        end

        def max_ranges
          light = 1.step(by: 100, to: 1_000)
          medium = 1_000.step(by: 1_000, to: 10_000)
          heavy = 10_000.step(by: 10_000, to: 100_000)

          light + medium + heavy
        end
      end

      class FetchParams < Params
        TYPES = %i[
          expires
          idle_heartbeat
          max_messages
          max_bytes
        ].freeze
      end

      class ConsumeParams < Params
        TYPES = %i[
          expires
          idle_heartbeat
          max_messages
          max_bytes
          threshold_messages
          threshold_bytes
        ].freeze

        def threshold_messages
          1.step(by: 50, to: 499).map do |messages|
            {threshold_messages: messages, max_messages: 1_000}
          end
        end

        def threshold_bytes
          100.step(by: 500, to: 4_999).map do |bytes|
            {threshold_bytes: bytes, max_bytes: 10_000}
          end
        end
      end
    end
  end
end
