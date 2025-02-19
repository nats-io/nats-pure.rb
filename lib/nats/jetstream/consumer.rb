# frozen_string_literal: true

require_relative "consumer/schemas"
require_relative "consumer/config"
require_relative "consumer/info"
require_relative "consumer/list"

module NATS
  class JetStream
    class Consumer
      attr_reader :config, :api

      def initialize(stream, config)
        @stream = stream
        @config = Config.new(config)
        @api = stream.api

        api.consumer.create(stream, config)
      end

      def update(values)
        config.update(values)
        api.consumer.update(stream, config)
      end

      def delete
        api.consumer.delete(stream, config)
      end

      def info
        api.consumer.delete(stream, config)
      end

      def next
      end

      def fetch(options)
      end

      def consume(options, &block)
      end
    end
  end
end
