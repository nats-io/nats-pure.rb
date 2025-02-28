# frozen_string_literal: true

require "monitor"

module NATS
  class JetStream
    class Subscription
      class Pull
        include MonitorMixin

        STATUSES = %i[pending processing draining closed]

        class Config < NATS::Utils::Config
          integer :expires, min: 1#, default: 30 # seconds 
          integer :idle_heartbeat #, default: 30 # seconds

          integer :max_messages, min: 1, default: 100 # 1_000_000 for max_bytes
          integer :max_bytes, min: 0

          integer :threshold_messages, min: 0, default: 50
          integer :threshold_bytes

          alias batch max_messages
        end

        attr_reader :consumer, :js, :config, :inbox, :handler, :messages, :heartbeats, :expiration

        def initialize(consumer, params = {}, &block)
          super()

          @consumer = consumer
          @js = consumer.js
          @handler = block

          @inbox = js.client.new_inbox
          @config = Config.new(params)
          @messages = Messages.new(self)

          @status = :pending
        end

        def execute
          return false unless pending?

          processing!

          schedule_expiration
          schedule_heartbeats

          setup_subscription
          request_messages
        end

        def drain
          draining!

          subscription.unsubscribe
          expiration.cancel
          heartbeats.cancel

          close!
        end

        def error(message)
        end

        STATUSES.each do |status|
          define_method "#{status}?" do
            @status == status
          end

          define_method "#{status}!" do
            @status = status
          end
        end

        private

        def setup_subscription
          @subscription = js.client.subscribe(inbox) do |message|
            message = ConsumerMessage.build(consumer, message)

            case message
            when ConsumerMessage
              handle_message(message)
            when IdleHeartBeatMessage
              handle_heartbeat(message)
            when WarningMessage
              handle_warning(message)
            else
              handle_error(message)
            end
          rescue => error
            #handle_error(error)
            puts error.message
            puts error.backtrace
          end
        end

        def request_messages
          js.api.consumer.msg.next(consumer.subject, config, reply_to: inbox)
        end

        def schedule_expiration
          @expiration = Concurrent::ScheduledTask.execute(config.expires) do
            synchronize { drain }
          end
        end

        def schedule_heartbeats
          @heartbeats = Concurrent::ScheduledTask.execute(config.idle_heartbeat) do
            handle_heartbeats_error
          end
        end
      end
    end
  end
end
