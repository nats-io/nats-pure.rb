# frozen_string_literal: true

require_relative "publisher/config"
require_relative "publisher/ack"

module NATS
  class JetStream
    class Publisher
      attr_reader :js

      def initialize(js)
        @js = js
      end

      def publish(subject, data, params = {})
        config = Config.new(params)

        message = begin
          js.client.request(
            subject,
            data,
            header: config.headers,
            timeout: config.timeout
          )
        rescue NATS::IO::NoRespondersError
          raise JetStream::NoStreamResponseError
        end

        Ack.build(message)
      end
    end
  end
end
