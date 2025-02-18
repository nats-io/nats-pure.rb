# frozen_string_literal: true

require_relative "stream/config"

module NATS
  class JetStream
    class Stream
      attr_reader :config, :api, :subject

      def initialize(client, config)
        @config = Config.new(config)
        @api = Api.new(client)

        @subject = config.name

        api.stream.create(subject, config)
      end

      def update(values)
        config.update(values)
        api.stream.update(subject, config)
      end

      def delete
        api.stream.delete(subject)
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
