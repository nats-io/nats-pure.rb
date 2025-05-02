# frozen_string_literal: true

module NATS
  class Compability
    class Test
      attr_reader :context, :client

      def initialize(context)
        @context = context
        @client = context.client
      end

      def run
        client.subscribe(subject) do |message|
          if message.data.empty?
            stop(message)
          else
            start(message)
          end
        rescue => error
          puts error.message
          puts error.backtrace
        end
      end

      def close
        @client.close
      end

      private

      def stop(message)
      end
    end
  end
end
