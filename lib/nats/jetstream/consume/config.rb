# frozen_string_literal: true

module NATS
  class JetStream
    class Consume < Pull
      class Config < Pull::Config
        integer :threshold_messages, min: 1
        integer :threshold_bytes, min: 0

        def initialize(values)
          super

          @max_messages ||= if max_bytes
            1_000_000
          else
            100
          end

          set_threshold(:messages)
          set_threshold(:bytes) if max_bytes
        end

        private

        def set_threshold(type)
          threshold = send("threshold_#{type}")
          max = send("max_#{type}")

          if threshold.nil?
            instance_variable_set("@threshold_#{type}", max / 2)
          elsif threshold >= max / 2
            raise NATS::JetStream::InvalidThresholdError.new(type)
          end
        end

        def ordered?
          false
        end
      end
    end
  end
end
