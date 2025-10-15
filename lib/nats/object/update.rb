# frozen_string_literal: true

require_relative "update/meta"

module NATS
  class Object
    class Update
      attr_reader :store

      def initialize(store)
        @store = store
      end

      def update(object, meta)
        object.reload

        meta = Meta.new(object, meta)

        raise Object::ObjectDeletedError if object.deleted?
        raise Object::NameTakenError if name_taken?(meta)

        publish(object, meta)
        delete(meta) if meta.changed?(:name)
      end

      private

      def publish(object, meta)
        object.info.update(**meta, mtime: Time.now)
        store.meta.publish(object.info.name, object.info)
      end

      def delete(meta)
        store.meta.purge(meta.info.name)
      end

      def name_taken?(meta)
        meta.changed?(:name) && store.meta.find(meta.name)
      end
    end
  end
end
