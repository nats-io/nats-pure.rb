# frozen_string_literal: true

module NATS
  class Service
    class Message < ::NATS::Msg
      attr_reader :error, :endpoint

      def initialize(service, message)
        super(
          subject: message.subject,
          reply: message.reply,
          data: message.data,
          header: message.header,
          nc: service.client
        )

        @error = nil
      end

      def error?
        !!@error
      end

      def respond_with_error(error)
        @error = NATS::Service::ErrorWrapper.new(error)

        message = dup
        message.subject = reply
        message.reply = ""
        message.data = @error.data

        message.header = {
          "Nats-Service-Error" => @error.message,
          "Nats-Service-Error-Code" => @error.code
        }

        respond_msg(message)
      end

      def inspect
        dot = "..." if @data.length > 10
        dat = "#{data.slice(0, 10)}#{dot}"
        "#<Service::Message(subject: \"#{@subject}\", reply: \"#{@reply}\", data: #{dat.inspect})>"
      end
    end
  end
end
