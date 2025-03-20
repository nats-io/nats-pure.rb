# frozen_string_literal: true

module NATS
  class JetStream
    class ConsumerMessage < Message
      attr_reader :consumer

      string :subject
      hash :header, default: {}
      string :raw_header
      string :data
      string :reply

      def initialize(consumer, message)
        @consumer = consumer
        @ack = Ack.new(self)

        super(
          subject: message.subject,
          header: message.header,
          raw_header: message.raw_header,
          data: message.data,
          reply: message.reply
        )
      end

      def bytesize
        [subject, raw_header, data, reply].compact.map(&:bytesize).sum
      end

      def ack(params = {})
        @ack.ack(params)
      end

      def nack(params = {})
        @ack.nack(params)
      end

      def term(params = {})
        @ack.term(params)
      end

      def in_progress(params = {})
        @ack.in_progress(params)
      end

      def acked?
        @ack.acked?
      end
    end
  end
end
