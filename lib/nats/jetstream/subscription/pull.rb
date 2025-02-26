# frozen_string_literal: true

require "monitor"

module NATS
  class JetStream
    class Subscription
      class Pull
        include MonitorMixin

        class Config < NATS::Utils::Config
          integer :expires, min: 1, default: 30 # seconds 
          integer :idle_heartbeat, default: 30

          integer :max_messages, min: 1, default: 100 # 1_000_000 for max_bytes
          integer :max_bytes, min: 0

          integer :threshold_messages, min: 0, default: 50
          integer :threshold_bytes
        end

        def initialize(jetstream, params = {})
          super()

          @jetstream = jetstream
          @config = Config.new(params)

          @inbox = client.new_inbox
          @in_progress = false
        end

        def in_progress?
          @in_progress
        end

        def done?
          !@in_progress
        end

        private

        def subscription
          @subscription ||= @client.subscribe(inbox) do |message|
            message = Message.build(stream, message)
            synchronize { handle(message) }
          end
        end

        def handle(message)
          case message
          when NoMessages, RequestTimeout, PullTerminated
            handle_termination(message)
          when UserMessage
            handle_message(message)
          else
            handle_error(message)
          end
        end

        def done!
          @in_progress = false
        end
      end
    end
  end
end
