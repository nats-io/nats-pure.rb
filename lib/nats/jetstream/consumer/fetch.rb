# frozen_string_literal: true

module NATS
  class JetStream
    class Consumer
      class Fetch
        include Enumerable

        def initialize(consumer, params)
          @consumer = consumer
          @subsciption = Subscription::Fetch.new(params)
        end

        def each
        end
      end
    end
  end
end
