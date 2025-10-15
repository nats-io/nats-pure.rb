# frozen_string_literal: true

require_relative "watcher/options"

module NATS
  class Object
    class Watcher
      include MonitorMixin

      attr_reader :store, :options

      def initialize(store, options = {})
        super()

        @store = store
        @options = Options.new(options)

        @queue = SizedQueue.new(32)
        @init_marker = @options.updates_only

        setup
      end

      def updates(timeout: 5)
        @queue.pop(timeout: timeout)
      rescue ThreadError
        nil
      end

      def stop
        @consume&.stop
        @queue.close
      end

      private

      def setup
        init_done if store_empty?

        @consume = store.meta.consume(">", options.consume) do |info|
          @queue << info if include?(info)

          synchronize do
            init_done if init_done?(info)
          end
        rescue ClosedQueueError
        end
      end

      def store_empty?
        !options.updates_only && store.stream.info.state.messages == 0
      end

      def include?(info)
        !options.ignore_deletes || !info.deleted?
      end

      def init_done?(info)
        !@init_marker && info.message.metadata.num_pending.zero?
      end

      def init_done
        @init_marker = true
        @queue << Marker.new
      end

      class Marker; end
    end
  end
end
