# frozen_string_literal: true

module NATS
  class Object
    class Put
      class Chunks
        attr_reader :store

        def initialize(store)
          @store = store
        end

        def publish(meta)
          chunks = ChunksInfo.new
          chunk_size = chunk_size(meta)

          until meta.data.eof?
            chunk = meta.data.read(chunk_size)

            store.chunks.publish(meta.nuid, chunk)
            chunks.published(chunk)
          end

          chunks
        ensure
          meta.data.close
        end

        private

        def chunk_size(meta)
          meta.options.max_chunk_size
        end
      end
    end
  end
end
