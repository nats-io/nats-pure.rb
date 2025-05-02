# frozen_string_literal: true

module NATS
  class Compability
    class ObjectStore
      class Watch < Test
        def start(message)
          store = context.stores.find("test")
          watcher = store.watch

          create = watcher.updates
          watcher.updates
          update = watcher.updates

          watcher.stop

          message.respond("#{create.digest},#{update.digest}")
        end

        def subject
          "tests.object-store.watch.>"
        end
      end
    end
  end
end
