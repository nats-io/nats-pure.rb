# frozen_string_literal: true

require_relative "get/info"
require_relative "get/chunks"

require_relative "get/options"
require_relative "get/data"

module NATS
  class Object
    class Get
      attr_reader :store

      def initialize(store)
        @store = store

        @info = Get::Info.new(store)
        @chunks = Get::Chunks.new(store)
      end

      def get(name, options = {})
        options = Options.new(options)

        info = @info.find(name, options)
        return link(info, options) if info.link?

        object(info, options)
      end

      private

      def link(info, options)
        bucket(info).get(info.link.name, options)
      end

      def bucket(info)
        return store if same_bucket?(info)
        store.context.stores.find(info.link.bucket)
      end

      def same_bucket?(info)
        info.link.bucket == info.bucket
      end

      def object(info, options)
        data =
          if options.lazy?
            Object::IO.new(store, info, options)
          else
            data(info, options)
          end

        Object.new(store, info, data)
      end

      def data(info, options)
        data = @chunks.get(info, options)

        data.data
      end
    end
  end
end
