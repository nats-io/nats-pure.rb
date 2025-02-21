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
          stream_name: stream.config.name,
          config: config,
          action: "update"
        )

        @config = response.data.config
        self
      end

      def delete
        js.api.consumer.delete(subject).success?
      end

      def info
        js.api.consumer.info(subject).data
      end

      def fetch(batch = 1, params = {})
        Fetch.new(self, batch: batch, **params)
      end

      def next(params)
        fetch(1, params)
      end

      def consume(params, &block)
        Consume.new(self, params, &block)
      end
    end
  end
end
