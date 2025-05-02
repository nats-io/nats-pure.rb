# frozen_string_literal: true

module NATS
  class JetStream
    class Context
      attr_reader :client, :api, :streams

      def initialize(client, params = {})
        @client = client

        @api = API.new(self, params)
        @publisher = Publisher.new(self)
        @streams = Stream::List.new(self)
      end

      def object_store
        @object_store ||= Object::Context.new(client, js: self)
      end
      alias_method :os, :object_store

      def info
        api.info.data
      end

      def publish(subject, data, params = {})
        @publisher.publish(subject, data, params)
      end
    end
  end
end
