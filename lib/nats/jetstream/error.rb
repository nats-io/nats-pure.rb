# frozen_string_literal: true

module NATS
  class JetStream
    # Error is any error that may arise when interacting with JetStream.
    class Error < NATS::IO::Error; end

    # When there is a NATS::IO::NoResponders error after making a publish request.
    class NoStreamResponseError < Error; end

    # When an invalid durable or consumer name was attempted to be used.
    class InvalidDurableNameError < Error; end

    # When an ack not longer valid.
    class InvalidJSAckError < Error; end

    # When an ack has already been acked.
    class MsgAlreadyAckdError < Error; end

    # When the delivered message does not behave as a message delivered by JetStream,
    # for example when the ack reply has unrecognizable fields.
    class NotJSMessageError < Error; end

    # When the stream name is invalid.
    class InvalidStreamNameError < Error; end

    # When the consumer name is invalid.
    class InvalidConsumerNameError < Error; end

    # When the server responds with an error from the JetStream API.
    class APIErrorError < Error
      attr_reader :code, :err_code, :description, :stream, :seq

      def initialize(params = {})
        @code = params[:code]
        @err_code = params[:err_code]
        @description = params[:description]
        @stream = params[:stream]
        @seq = params[:seq]
      end

      def to_s
        "#{@description} (status_code=#{@code}, err_code=#{@err_code})"
      end
    end

    # When JetStream is not currently available, this could be due to JetStream
    # not being enabled or temporarily unavailable due to a leader election when
    # running in cluster mode.
    # This condition is represented with a message that has 503 status code header.
    class ServiceUnavailableError < APIError
      def initialize(params = {})
        super
        @code ||= 503
      end
    end

    # When there is a hard failure in the JetStream.
    # This condition is represented with a message that has 500 status code header.
    class ServerErrorError < APIError
      def initialize(params = {})
        super
        @code ||= 500
      end
    end

    # When a JetStream object was not found.
    # This condition is represented with a message that has 404 status code header.
    class NotFoundError < APIError
      def initialize(params = {})
        super
        @code ||= 404
      end
    end

    # When the stream is not found.
    class StreamNotFoundError < NotFound; end

    # When the consumer or durable is not found by name.
    class ConsumerNotFoundError < NotFound; end

    # When the JetStream client makes an invalid request.
    # This condition is represented with a message that has 400 status code header.
    class BadRequestError < APIError
      def initialize(params = {})
        super
        @code ||= 400
      end
    end
  end
end
