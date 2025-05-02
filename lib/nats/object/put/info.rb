# frozen_string_literal: true

module NATS
  class Object
    class Put
      class Info
        attr_reader :store

        def initialize(store)
          @store = store
        end

        def publish(meta, chunks)
          info = {
            **meta,
            **chunks,
            bucket: store.config.bucket
          }

          store.meta.publish(meta.name, info)
        end
      end
    end
  end
end
