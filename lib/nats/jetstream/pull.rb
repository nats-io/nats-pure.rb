# frozen_string_literal: true

require_relative "pull/config"
require_relative "pull/buffer"
require_relative "pull/subscription"
require_relative "pull/monitor"
require_relative "pull/handler"

require_relative "pull/fetch"
require_relative "pull/consume"

module NATS
  class JetStream
    class Pull
      include MonitorMixin

      STATUSES = %i[pending processing draining closed]

      attr_reader :js, :consumer, :last_error
      attr_reader :config, :buffer, :subscription, :handler, :monitor

      def initialize(consumer, params = {})
        super()

        @consumer = consumer
        @js = consumer.js

        @status = :pending
        @closed_cond = new_cond

        @last_error = nil
      end

      def start
        synchronize do
          return false unless pending?
          processing!

          monitor.start
          subscription.start
          request_messages
        end
      end

      def drain
        synchronize do
          return false unless processing?
          draining!

          subscription.drain
          monitor.stop

          closed! if handler.drained?
        end
      end

      def error(message)
        synchronize do
          @last_error = message
        end
      end

      def request_messages
        js.api.consumer.msg.next(
          consumer.subject,
          config,
          reply_to: subscription.inbox
        )
      end

      STATUSES.each do |status|
        define_method "#{status}?" do
          @status == status
        end

        define_method "#{status}!" do
          @status = status
        end
      end

      def closed!
        return if closed?
        @status = :closed
        @closed_cond.signal
      end
    end
  end
end
