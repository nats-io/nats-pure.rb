# frozen_string_literal: true

require "monitor"

module NATS
  class JetStream
    class PullSubscription
      include MonitorMixin

      class Config < NATS::Utils::Config
        integer :expires, min: 0
        integer :idle_heartbeat, default: 30

        integer :max_messages, default: 1
        integer :max_bytes, default: -1
      end

      def initialize(client, params = {})
        super()

        @client = client
        @config = Config.new(params)
        @inbox = client.new_inbox

        @in_progress = false
        @messages = []
        @messages_fetched = 0
        @bytes_fetched = 0
      end

      def in_progress?
        @in_progress
      end

      def done?
        !@in_progress
      end

      def drain
      end

      private

      def subscription
        @subscription ||= @client.subscribe(inbox) do |message|
          #return if done?
          response = Response.build(stream, message)

          case response
          when NoMessages, RequestTimeout, MaxBytesExceeded
            synchronize { done! }
          when Message
            synchronize { push(message) }
          else
            raise "error"
          end
        end
      end

      def push(message)
        @messages << message
        @messages_fetched += 1
        @bytes_fetched += message.bytesize

        done! if full?
      end

      def full?
        if config.max_messages
          @messages_fetched == config.max_messages
        else 
          @bytes_fetched >= config.max_bytes
        end
      end

      def done!
        @in_progress = false
      end
    end
  end
end
