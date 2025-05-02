# frozen_string_literal: true

module NATS
  class Compability
    class ObjectStore
      class PutLink < Test
        def start(message)
          store = context.stores.find("test")

          store.link(
            name: "link",
            to: {bucket: "test", name: "nats-server.zip"}
          )

          message.respond("")
        end

        def subject
          "tests.object-store.put-link.>"
        end
      end
    end
  end
end
