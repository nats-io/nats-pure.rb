# frozen_string_literal: true

require_relative "consumer/schemas"
require_relative "consumer/config"
require_relative "consumer/info"
require_relative "consumer/list"
require_relative "consumer/fetch"

module NATS
  class JetStream
    class Consumer
      attr_reader :js, :stream, :config, :subject

      def initialize(stream, config)
        @stream = stream
        @js = stream.js

        @config = Config.new(config)
        @subject = "#{@stream.subject}.#{@config.name}"
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

      def fetch(params = {})
        Fetch.new(self, params)
      end

      def next(params = {})
        fetch(params.merge(max_messages: 1)).first
      end

      def consume(params = {}, &block)
        consume = Consume.new(self, params, &block)
        consume.start
        consume
      end
    end
  end
end
