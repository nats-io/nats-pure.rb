# frozen_string_literal: true

module NATS
  class Object
    class Store
      class Meta < Subject
        def publish(object, data)
          info = Object::Info.new(data)
          js.publish(subject(object), info.to_json, rollup: "sub")

          info
        end

        private

        def subject(object)
          if object != ">"
            object = Base64.urlsafe_encode64(object)
          end

          "$O.#{store.config.bucket}.M.#{object}"
        end

        def to_object(message)
          Object::Info.new(**message.json, message: message)
        end
      end
    end
  end
end
