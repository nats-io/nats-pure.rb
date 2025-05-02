# frozen_string_literal: true

require_relative "put/info"
require_relative "put/chunks"

require_relative "put/meta"
require_relative "put/chunks_info"

module NATS
  class Object
    class Put
      attr_reader :store

      def initialize(store)
        @store = store

        @info = Info.new(store)
        @chunks = Chunks.new(store)
      end

      def put(meta)
        meta = Meta.new(nuid: store.nuid.next, **meta)
        existing = store.meta.find(meta.name)

        chunks = @chunks.publish(meta)
        info = @info.publish(meta, chunks)

        purge(existing)

        Object.new(store, info, meta.data)
      end

      private

      def purge(existing)
        if existing && !existing.deleted?
          store.chunks.purge(existing.nuid)
        end
      end
    end
  end
end
