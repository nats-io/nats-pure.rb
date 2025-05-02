# frozen_string_literal: true

module NATS
  class Compability
    class ObjectStore
      class GetObject < Test
        def start(message)
          store = context.stores.find("test")
          object = store.get("nats-server.zip", as: :string)

          message.respond(Digest::SHA256.digest(object.data))
        end

        def subject
          "tests.object-store.get-object.>"
        end
      end
    end
  end
end
