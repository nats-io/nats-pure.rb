# frozen_string_literal: true

require_relative "stream/config"

module NATS
  class JetStream
    class Stream
      def initialize(config)
        @config = Config.new(config)
        @stream = API.stream.create(config)
      end

      def update(config)
        @stream = API.stream.update(config)
      end

      def delete
        API.stream.delete(config)
      end

      def publish(message, options)
      end

      def messages
      end

      def info
        API.stream.info(config)
      end

      def purge(options)
        API.stream.purge(config)
      end
    end
  end
end
