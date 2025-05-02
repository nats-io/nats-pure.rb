# frozen_string_literal: true

module NATS
  class Compability
    class ObjectStore
      class UpdateMetadata < Test
        def start(message)
          store = context.stores.find("test")
          object = store.get("nats-server.zip")

          object.update(
            name: "new-thing.zip",
            description: "a new thing"
          )

          message.respond("")
        end

        def subject
          "tests.object-store.update-metadata.>"
        end
      end
    end
  end
end
