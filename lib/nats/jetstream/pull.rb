# frozen_string_literal: true

require_relative "pull/config"
require_relative "pull/buffer"
require_relative "pull/subscription"
require_relative "pull/heartbeats"
require_relative "pull/handler"

module NATS
  class JetStream
    class Pull
      include MonitorMixin

      STATUSES = %i[pending processing draining closed]

      attr_reader :js, :consumer, :error, :config
      attr_reader :buffer, :subscription, :handler, :monitor, :heartbeats

      def initialize(consumer, params = {})
        super()

        @consumer = consumer
        @js = consumer.js

        @status = :pending
        @closed_cond = new_cond

        @error = nil
      end

      def start
        synchronize do
          return false unless pending?
          processing!

          subscription.start
          request_messages

          heartbeats.start
          monitor.start
        end
      end

      def drain(error = nil)
        synchronize do
          return false unless processing?
          draining!

          @error = error

          subscription.drain
          heartbeats.stop
          monitor.stop

          closed! if handler.drained?
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
