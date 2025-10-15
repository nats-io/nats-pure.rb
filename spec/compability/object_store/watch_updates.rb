# frozen_string_literal: true

module NATS
  class Compability
    class ObjectStore
      class WatchUpdates < Test
        def start(message)
          store = context.stores.find("test")

          watcher = store.watch

          watcher.updates
          watcher.updates
          update = watcher.updates

          watcher.stop

          message.respond(update.digest)
        end

        def subject
          "tests.object-store.watch-updates.>"
        end
      end
    end
  end
end
