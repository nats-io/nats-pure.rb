# frozen_string_literal: true

module NATS
  class JetStream
    class StatusMessage
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
  end
end
