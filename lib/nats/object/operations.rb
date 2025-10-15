# frozen_string_literal: true

require_relative "put"
require_relative "get"
require_relative "link"
require_relative "update"
require_relative "delete"

module NATS
  class Object
    class Operations
      def initialize(store)
        @store = store

        @put = Put.new(store)
        @get = Get.new(store)
        @link = Link.new(store)
        @update = Update.new(store)
        @delete = Delete.new(store)
      end

      def put(meta)
        @put.put(meta)
      end

      def get(name, options)
        @get.get(name, options)
      end

      def link(name, to)
        @link.link(name, to)
      end

      def update(object, meta)
        @update.update(object, meta)
      end

      def delete(object)
        @delete.delete(object)
      end
    end
  end
end
