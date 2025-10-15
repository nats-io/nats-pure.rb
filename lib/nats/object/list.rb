# frozen_string_literal: true

module NATS
  class Object
    class List
      include Enumerable

      attr_reader :store, :options

      def initialize(store, options)
        @store = store
        @options = options
      end

      def each(&block)
        iterator.each(&block)
      end

      private

      def watcher
        @watcher ||= store.watch(ignore_deletes: !options[:show_deleted])
      end

      def iterator
        @iterator ||= Enumerator.new do |objects|
          info = watcher.updates

          until marker?(info)
            objects << object(info)
            info = watcher.updates
          end

          watcher.stop
        end
      end

      def marker?(info)
        info.nil? || info.is_a?(Watcher::Marker)
      end

      def object(info)
        Object.new(self, info, Object::IO.new(store, info))
      end
    end
  end
end
