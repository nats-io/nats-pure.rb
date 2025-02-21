# frozen_string_literal: true

require "monitor"

module NATS
  class JetStream
    class Consumer
      class PullSubscription
        include MonitorMixin

        attr_reader :consumer

        def initialize(consumer, &block)
          super()

          @consumer = consumer
          @block = block
        end
      end
    end
  end
end
