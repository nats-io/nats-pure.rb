# frozen_string_literal: true

module NATS
  class JetStream
    class Consumer
      attr_reader :stream, :config

      def initialize(config)
        @config = Config.new(config)
        @consumer = Manager.add_consumer(stream, config)
      end

      def update(config)
      end

      def delete
        Manager.delete_consumer(stream, self)
      end

      def info
        Manager.consumer_info(stream, self)
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
