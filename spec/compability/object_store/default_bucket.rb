# frozen_string_literal: true

module NATS
  class Compability
    class ObjectStore
      class DefaultBucket < Test
        def start(message)
          context.stores.create(bucket: "test")
          message.respond("")
        end

        def subject
          "tests.object-store.default-bucket.>"
        end
      end
    end
  end
end
