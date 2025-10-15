# frozen_string_literal: true

module NATS
  class JetStream
    class Consumer
      class Fetch
        include Enumerable

        attr_reader :consumer, :params, :fetch

        def initialize(consumer, params)
          @consumer = consumer
          @params = params

          @fetch = JetStream::Fetch.new(consumer, params)
          @fetch.start
          @fetch.wait
        end

        def each(&block)
          fetch.messages.each(&block)
        end

        def error
          fetch.error
        end
      end
    end
  end
end
