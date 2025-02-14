# frozen_string_literal: true

require_relative "stream/config"

module NATS
  class JetStream
    class Stream
      def initialize(client, config)
        @client = client
        @config = Config.new(config)
        @api = Api.new(client)

        @stream = api.stream.create(config)
      end

      def update(config)
        @stream = api.stream.update(config)
      end

      def delete
        api.stream.delete(config)
      end

      def publish(message, options)
      end

      def messages
      end

      def info
        api.stream.info(config)
      end

      def purge(options)
        api.stream.purge(config)
      end
    end
  end
end
