# frozen_string_literal: true

require_relative "stream/schemas"
require_relative "stream/config"
require_relative "stream/state"
require_relative "stream/info"
require_relative "stream/list"

module NATS
  class JetStream
    class Stream
      attr_reader :jetstream, :config, :subject

      alias js jetstream

      def initialize(jetstream, config)
        @jetstream = jetstream
        @config = Config.new(config)
        @subject = @config.name
      end

      def create
        response = js.api.stream.create(subject, config)
        config.update(response.data.config)

        self
      end

      def update(values)
        config.update(values)

        response = js.api.stream.update(subject, config)
        config.update(response.data.config)

        self
      end

      def delete
        response = js.api.stream.delete(subject)
        response.data.success
      end

      def info
        js.api.stream.info(subject).data
      end

      def purge
        response = js.api.stream.purge(subject)
        response.data.success
      end

      def messages
      end
    end
  end
end
