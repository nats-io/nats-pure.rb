# frozen_string_literal: true

module NATS
  class Object
    class Delete
      attr_reader :store

      def initialize(store)
        @store = store
      end

      def delete(object)
        object.reload

        raise Object::ObjectDeletedError if object.deleted?

        store.chunks.purge(object.info.nuid)
        purge_info(object.info)

        true
      end

      def purge_info(info)
        info.update(
          deleted: true,
          size: 0,
          chunks: 0,
          digest: ""
        )

        store.meta.publish(info.name, info)
      end
    end
  end
end
