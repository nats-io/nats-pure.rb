# frozen_string_literal: true

module NATS
  class JetStream
    class StatusMessage
      attr_reader :consumer, :message

      def initialize(consumer, message)
        @consumer = consumer
        @message = message
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

    class WarningMessage < StatusMessage
      def pull_terminated?
        !pending_messages.zero? || !pending_bytes.zero?
      end

      def pending_messages
        message.header["Nats-Pending-Messages"].to_i
      end

      def pending_bytes
        message.header["Nats-Pending-Bytes"].to_i
      end
    end

    class ErrorMessage < StatusMessage; end

    class NoMessagesMessage < WarningMessage; end

    class RequestTimeoutMessage < WarningMessage; end

    class MaxRequestBatchMessage < WarningMessage; end

    class MaxRequestExpiresMessage < WarningMessage; end

    class MaxRequestMaxBytesMessage < WarningMessage; end

    class MaxWaitingMessage < WarningMessage; end

    class MaxBytesExceededMessage < WarningMessage; end

    class BatchCompletedMessage < WarningMessage; end

    class BadRequestMessage < ErrorMessage; end

    class ConsumerDeletedMessage < ErrorMessage; end

    class ConsumerLeadershipChangedMessage < ErrorMessage; end

    class NoRespondersMessage < ErrorMessage; end
  end
end
