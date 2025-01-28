# frozen_string_literal: true

module NATS
  class Service
    class Error < StandardError; end

    class InvalidNameError < Error; end

    class InvalidVersionError < Error; end

    class InvalidQueueError < Error; end

    class InvalidSubjectError < Error; end

    class ErrorWrapper
      attr_reader :code, :message, :data

      def initialize(error)
        case error
        when Exception
          @code = 500
          @message = error.message
          @data = ""
        when Hash
          @code = error[:code]
          @message = error[:description]
          @data = error[:data]
        when ErrorWrapper
          @code = error.code
          @message = error.message
          @data = error.data
        else
          @code = 500
          @message = error.to_s
          @data = ""
        end
      end

      def description
        "#{code}:#{message}"
      end
    end
  end
end
