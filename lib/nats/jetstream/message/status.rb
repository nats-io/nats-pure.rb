# frozen_string_literal: true

module NATS
  class JetStream
    class StatusMessage
      #Errors:
      #400 Bad Request
      #409 Consumer Deleted
      #409 Consumer is push based

      #Warnings:
      #409 Exceeded MaxRequestBatch of %d
      #409 Exceeded MaxRequestExpires of %v
      #409 Exceeded MaxRequestMaxBytes of %v
      #409 Exceeded MaxWaiting

      #Not Telegraphed:
      #404 No Messages
      #408 Request Timeout
      #409 Message Size Exceeds MaxBytes
      STATUSES = {
        "100" => :control_message,
        "400" => :bad_request,
        "404" => :no_messages,
        "408" => :request_timeout,
        "409" => :pull_terminated,
        "503" => :no_responders
      }.freeze

      attr_reader :consumer, :code, :description

      def initialize(consumer, message)
        @consumer = consumer
        @code = message.header["Status"]
        @description = message.header["Description"]
      end

      def status
        STATUSES[code]
      end

      def inspect
        "@code=#{code}, @description=#{description}"
      end
    end

    class IdleHeartbeatMessage < StatusMessage
    end

    class IdleHeartbeatMessage < StatusMessage
    end
  end
end
