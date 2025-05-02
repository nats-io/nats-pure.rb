# frozen_string_literal: true

module NATS
  class Object
    class Get
      class Info
        attr_reader :store

        def initialize(store)
          @store = store
        end

        def find(name, options)
          info = store.meta.find(name)

          if info.nil? || deleted?(info, options)
            raise NATS::Object::ObjectNotFoundError
          end

          info
        end

        private

        def deleted?(info, options)
          info.deleted? && !options.show_deleted
        end
      end
    end
  end
end
