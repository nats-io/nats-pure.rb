# frozen_string_literal: true

module NATS
  class JetStream
    class StatusMessage
      attr_reader :consumer

      def initialize(consumer, message)
        @consumer = consumer
      end

      def code
        message.header["Status"]
      end

      def description
        message.header["Description"]
      end

      def inspect
        "#<#{self.class} @code=#{code}, @description=#{description}>"
      end
    end

    class IdleHeartbeatMessage < StatusMessage
    end

    class ErrorMessage < StatusMessage; end
    class WarningMessage < StatusMessage; end

    class BadRequestMessage < ErrorMessage; end
    class NoMessagesMessgage < WarningMessage; end

    class RequestTimeout < WarningMessage; end
    class MaxBytesExceededMessage < WarningMessage; end
    class BatchCompletedMessage < WarningMessage; end

    class ConsumerDeletedMessage < ErrorMessage; end
    class ConsumerLeadershipChangedMessage < ErrorMessage; end

    class NoRespondersMessage < ErrorMessage; end
  end
end
