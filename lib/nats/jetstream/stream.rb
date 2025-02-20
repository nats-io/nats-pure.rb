# frozen_string_literal: true

require_relative "stream/schemas"
require_relative "stream/config"
require_relative "stream/state"
require_relative "stream/info"
require_relative "stream/list"

module NATS
  class JetStream
    class Stream
      attr_reader :jetstream, :config, :subject, :messages

      alias js jetstream

      def initialize(jetstream, config)
        @jetstream = jetstream

        @config = Config.new(config)
        @subject = @config.name

        @messages = Message::List.new(self)
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
        js.api.stream.delete(subject).success?
      end

      def info(params = {})
        js.api.stream.info(subject, params).data
      end

      def purge(params = {})
        js.api.stream.purge(subject, params).success?
      end
    end
  end
end
