# frozen_string_literal: true

module NATS
  class Client
    class StatusListeners
      class Status
        STATUSES = %i[
          disconnected
          connected
          closed
          reconnecting
          connecting
          draining_subs
          draining_pubs
        ].freeze

        def initialize(status)
          @status = status
        end

        STATUSES.each do |status|
          define_method "#{status}?" do
            @status == NATS::Status.const_get(status.upcase)
          end
        end
      end

      include MonitorMixin

      def initialize
        super
        @listeners = []
      end

      def create
        synchronize do
          listener = SizedQueue.new(10)
          @listeners << listener

          listener
        end
      end

      def send(status)
        synchronize do
          # Iterate over dup as delete shift the
          # next element to the position of the
          # deleted one making each skip it
          @listeners.dup.each do |listener|
            listener.push(Status.new(status))
          rescue ClosedQueueError
            @listeners.delete(listener)
          end
        end
      end

      def close
        synchronize do
          @listeners.each(&:close)
        end
      end
    end
  end
end
