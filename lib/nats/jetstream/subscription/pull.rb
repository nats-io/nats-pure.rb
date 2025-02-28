# frozen_string_literal: true

require "monitor"

module NATS
  class JetStream
    class Subscription
      class Pull
        include MonitorMixin

        class Config < NATS::Utils::Config
          integer :expires, min: 1#, default: 30 # seconds 
          integer :idle_heartbeat #, default: 30 # seconds

          integer :max_messages, min: 1, default: 100 # 1_000_000 for max_bytes
          integer :max_bytes, min: 0

          integer :threshold_messages, min: 0, default: 50
          integer :threshold_bytes
        end

        attr_reader :consumer, :jetstream, :config, :inbox

        alias js jetstream

        def initialize(consumer, params = {}, &block)
          super()

          @consumer = consumer
          @jetstream = consumer.jetstream
          @config = Config.new(params)
          @handler = block

          @inbox = js.client.new_inbox
          @in_progress = false
        end

        def start
          @in_progress = true
          subscription
          request
        end

        def in_progress?
          @in_progress
        end

        def done?
          !@in_progress
        end

        private

        def request
          js.api.consumer.msg.next(
            consumer.subject,
            {
              expires: config.expires,
              batch: config.max_messages,
              max_bytes: config.max_bytes,
              idle_heartbeat: config.idle_heartbeat
            },
            reply_to: inbox
          )
        end

        def subscription
          @subscription ||= js.client.subscribe(inbox) do |message|
            puts "MESSAGE: #{message.inspect}"
            message = ConsumerMessage.build(consumer, message)
            puts "CONSUMER MESSAGE: #{message.inspect}"

            if message.termination?
              handle_termination(message)
            elsif message.error?
              handle_error(message)
            else
              handle_message(message)
            end
          rescue => error
            puts error.message
            puts error.backtrace
          end
        end

        def done!
          @in_progress = false
        end
      end
    end
  end
end
