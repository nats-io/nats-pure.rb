# frozen_string_literal: true

module NATS
  class JetStream
    # Error is any error that may arise when interacting with JetStream.
    class Error < NATS::IO::Error; end

    class InvalidIdleHeartbeatError < Error
      def message
        "expires should be at least 2 times idle_heartbeat"
      end
    end

    class InvalidThresholdError < Error
      def initialize(type)
        @type = type
      end

      def message
        "max_#{@type} should be at least 2 times threshold_#{@type}"
      end
    end

    class MessageAckedError < Error
      def message
        "messages has already been acked"
      end
    end

    class ApiError < JetStream::Error
      attr_reader :code, :err_code, :description

      def initialize(data)
        @code = data.code
        @err_code = data.err_code
        @description = data.description
      end

      def to_s
        "#{description} (status_code=#{code}, err_code=#{err_code})"
      end
    end

    class ServiceUnavailableError < ApiError; end

    class ServerError < ApiError; end

    class NotFoundError < ApiError; end

    class StreamNotFoundError < NotFoundError; end

    class ConsumerNotFoundError < NotFoundError; end

    class MessageNotFoundError < NotFoundError; end

    class BadRequestError < ApiError; end

    class ConsumerExistsError < BadRequestError; end
  end
end
