# frozen_string_literal: true

module NATS
  class Compability
    class ObjectStore
      class PutObject < Test
        def start(message)
          store = context.stores.find("test")

          store.put(
            name: "nats-server.zip",
            description: "a nats server",
            data: URI(url).open
          )

          message.respond("")
        end

        def subject
          "tests.object-store.put-object.>"
        end

        def url
          "https://github.com/nats-io/nats-server/releases/download/v2.9.19/nats-server-v2.9.19-linux-arm64.zip"
        end
      end
    end
  end
end
