# frozen_string_literal: true

module NATS
  class Object
    class Chunk
      attr_reader :message

      def initialize(message)
        @message = message
      end

      def data
        @message.data
      end

      def last?
        @message.metadata.num_pending.zero?
      end
    end
  end
end
