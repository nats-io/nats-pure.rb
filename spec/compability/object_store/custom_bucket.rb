# frozen_string_literal: true

module NATS
  class Compability
    class ObjectStore
      class CustomBucket < Test
        def start(message)
          context.stores.create(
            bucket: "customized",
            description: "desc",
            ttl: 180000000000,
            max_bytes: 64000,
            storage: "memory",
            num_replicas: 1,
            compression: "none"
          )

          message.respond("")
        end

        def subject
          "tests.object-store.custom-bucket.>"
        end
      end
    end
  end
end
