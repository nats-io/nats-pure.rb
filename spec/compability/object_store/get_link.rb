# frozen_string_literal: true

module NATS
  class Compability
    class ObjectStore
      class GetLink < Test
        def start(message)
          store = context.stores.find("test")
          object = store.get("link", as: :string)

          message.respond(Digest::SHA256.digest(object.data))
        end

        def subject
          "tests.object-store.get-link.>"
        end
      end
    end
  end
end
