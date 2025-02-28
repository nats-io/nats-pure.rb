# frozen_string_literal: true

require "monitor"

module NATS
  class JetStream
    class Subscription
      class Pull
        include MonitorMixin

        STATUSES = %i[pending processing draining closed]

        class Config < NATS::Utils::Config
          integer :expires, min: 1, default: 30 * 10**9
          integer :idle_heartbeat, default: 15 * 10**9

          integer :max_messages, min: 1, default: 100 # 1_000_000 for max_bytes
          integer :max_bytes, min: 0

          integer :threshold_messages, min: 0, default: 50
          integer :threshold_bytes

          alias batch max_messages
        end

        attr_reader :consumer, :js, :config, :inbox, :handler, :messages, :heartbeats, :expiration, :subscription

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
          puts "Draining (#{Thread.current.object_id})"
          draining!

          js.client.send(:drain_sub, subscription)
          expiration.cancel
          heartbeats.cancel

          closed!
        end

        def error(message)
          @error = message
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
            puts "Message: #{message.inspect} (#{Thread.current.object_id})"

            case message
            when ConsumerMessage
              handle_message(message)
            when IdleHeartbeatMessage
              handle_heartbeat(message)
            when WarningMessage
              handle_warning(message)
            else
              handle_error(message)
            end
          rescue => error
            puts error.message
            puts error.backtrace
            handle_error(error)
          end
        end

        def request_messages
          js.api.consumer.msg.next(consumer.subject, config, reply_to: inbox)
        end

        def schedule_expiration
          @expiration = Concurrent::ScheduledTask.execute(config.expires) do
            puts "Expired"
            synchronize { drain }
          end
        end

        def schedule_heartbeats
          @heartbeats = Concurrent::ScheduledTask.execute(2 * config.idle_heartbeat) do
            puts "No Heartbeats"
            handle_no_heartbeats
          end
        end
      end
    end
  end
end
