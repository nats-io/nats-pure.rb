# frozen_string_literal: true

module NATS
  class Object
    class Link
      attr_reader :store, :context

      def initialize(store)
        @store = store
        @context = store.context
      end

      def link(name, object)
        object = find(object)

        raise Object::ObjectNotFoundError if object.nil?
        raise Object::ObjectDeletedError if object.deleted?
        raise Object::NoLinkToLinkError if object.link?
        raise Object::ObjectExistsError if exists?(name)

        info = publish(name, object)

        Object.new(store, info)
      end

      private

      def find(object)
        bucket = link_bucket(object)
        name = link_name(object)

        bucket.meta.find(name)
      end

      def link_bucket(object)
        case object
        when NATS::Object
          object.store
        when Hash
          context.stores.find(object[:bucket])
        else
          raise Object::NotLinkError
        end
      end

      def link_name(object)
        case object
        when NATS::Object
          object.info.name
        when Hash
          object[:name]
        else
          raise Object::NotLinkError
        end
      end

      def exists?(name)
        object = store.meta.find(name)
        object && !object.link?
      end

      def publish(name, object)
        info = {
          name: name,
          bucket: store.config.bucket,
          nuid: store.nuid.next,
          options: {
            link: {bucket: object.bucket, name: object.name}
          }
        }

        store.meta.publish(name, info)
      end
    end
  end
end
