# frozen_string_literal: true

require_relative "message/info"
require_relative "message/list"

module NATS
  class JetStream
    class Message
      attr_reader :stream, :info

      def initialize(stream, info)
        @stream = stream
        @info = info
      end

      def delete
        js.api.stream.msg.delete(info.seq).success?
      end
    end
  end
end
