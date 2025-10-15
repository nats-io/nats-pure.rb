# frozen_string_literal: true

module NATS
  class Object
    class Store
      class Chunks < Subject
        def publish(object, data)
          js.publish(subject(object), data)
          data
        end

        private

        def subject(object)
          "$O.#{store.config.bucket}.C.#{object}"
        end

        def to_object(message)
          Object::Chunk.new(message)
        end
      end
    end
  end
end
