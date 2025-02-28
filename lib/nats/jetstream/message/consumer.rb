# frozen_string_literal: true

module NATS
  class JetStream
    class ConsumerMessage < Message
      attr_reader :consumer

      string :subject
      hash :header, default: {}
      string :data
      string :reply

      def initialize(consumer, message)
        @consumer = consumer

        super(
          subject: message.subject,
          header: message.header,
          data: message.data,
          reply: message.reply
        )
      end

      def bytesize
        #subject.bytesize + header.bytesize + data.bytesize + reply.bytesize
        subject.bytesize + data.bytesize + reply.bytesize
      end
    end
  end
end
