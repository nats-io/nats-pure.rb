# frozen_string_literal: true

module NATS
  class JetStream
    class Consumer
      class Fetch
        include Enumerable

        attr_reader :consumer

        class Config < NATS::Utils::Config
          integer :expires, min: 0
          integer :idle_heartbeat, default: 30

          integer :max_messages, default: 1
          integer :max_bytes, default: -1
        end

        def initialize(consumer, batch: 1, params = {})
          @config = Config.new(params)

          @inbox = client.new_inbox
        end

        def each(&block)
          enumerator.each(&block)
        end

        private

        def enumerator
          @enumeartor ||= Enumerator.new do |yielder|
          end
        end

        def subscription
          client.subscribe(inbox) do |message|
            message = Message.new(stream, message)
          end
        end
      end
    end
  end
end
