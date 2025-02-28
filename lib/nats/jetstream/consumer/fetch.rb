# frozen_string_literal: true

module NATS
  class JetStream
    class Consumer
      class Fetch
        include Enumerable

        def initialize(consumer, params)
          @consumer = consumer
        end

        def each(&block)
          @subsciption = Subscription::Fetch.new(params, &block)

          until subscription.done?
          end
        end
      end
    end
  end
end
