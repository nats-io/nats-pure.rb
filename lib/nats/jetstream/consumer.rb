# frozen_string_literal: true

require_relative "consumer/schemas"
require_relative "consumer/config"
require_relative "consumer/info"
require_relative "consumer/list"

module NATS
  class JetStream
    class Consumer
      attr_reader :jetstream, :config, :subject

      alias js jetstream

      def initialize(stream, config)
        @stream = stream
        @jetstream = stream.jetstream

        @config = Config.new(config)
        @subject = "#{stream.subject}.#{config.name}"
      end

      def update(config)
        response = js.api.consumer.create(
          subject,
          stream_name: stream.name,
          config: config,
          action: "update"
        )

        @config = response.data.config
        self
      end

      def delete
        api.consumer.delete(subject).success?
      end

      def info
        api.consumer.delete(subject).data
      end

      def next
      end

      def fetch(params)
      end

      def consume(params, &block)
      end
    end
  end
end
