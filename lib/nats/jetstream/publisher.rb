# frozen_string_literal: true

require_relative "publisher/options"
require_relative "publisher/ack"

module NATS
  class JetStream
    class Publisher
      attr_reader :js

      def initialize(jetstream)
        @js = jetstream
      end

      def publish(subject, data, params = {})
        options = Options.new(params)

        message = begin
          js.client.request(
            subject,
            data,
            header: options.header,
            timeout: options.timeout
          )
        rescue NATS::IO::NoRespondersError
          raise JetStream::NoStreamResponseError
        end

        Ack.build(message)
      end
    end
  end
end
