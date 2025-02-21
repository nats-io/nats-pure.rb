# frozen_string_literal: true

module NATS
  class JetStream
    class Consumer
      class Consume
        attr_reader :consumer

        class Config < NATS::Utils::Config
          # next
          integer :expires
          integer :idle_heartbeat, default: 30

          # fetch
          integer :max_messages, default: 1
          integer :max_bytes, default: -1

          # consume
          integer :threshold_messages
          integer :threshold_bytes
        end

        def initialize(consumer, batch = 1, params = {})
          config = Config.new(params)
        end
      end
    end
  end
end
