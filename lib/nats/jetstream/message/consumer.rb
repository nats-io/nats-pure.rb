# frozen_string_literal: true

module NATS
  class JetStream
    class ConsumerMessage < Message
      attr_reader :consumer

      string :subject
      hash :header, default: {}
      string :data

      def initialize(consumer, message)
        @consumer = consumer

        super(
          subject: message.subject,
          header: message.header,
          data: message.data
        )
      end
    end
  end
end
