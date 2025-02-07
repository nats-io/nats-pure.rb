# frozen_string_literal: true

module NATS
  class JetStream
    class Context
      attr_reader :client, :api, :streams

      def initialize(client, params = {})
        @client = client

        @api = Api.new(self, params[:prefix])
        @streams = Stream::List.new(self)
      end

      def info
        api.info.data
      end
    end
  end
end
