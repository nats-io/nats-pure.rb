# frozen_string_literal: true

require_relative "message/info"
require_relative "message/list"

module NATS
  class JetStream
    class Message
      attr_reader :stream

      def initialize(stream)
        @stream = stream
      end
    end
  end
end
