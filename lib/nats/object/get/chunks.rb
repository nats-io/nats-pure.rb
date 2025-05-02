# frozen_string_literal: true

module NATS
  class Object
    class Get
      class Chunks
        attr_reader :store

        def initialize(store)
          @store = store
        end

        def get(info, options)
          return if info.no_data?
          data = Data.new(info, options)

          consume(info) do |chunk, pull|
            write(data, chunk)
            stop(data, pull) if chunk.last?
          rescue
            stop(data, pull)
          end

          wait(data, options)
          data
        end

        private

        def consume(info)
          store.chunks.consume(info.nuid) do |message, pull|
            yield message, pull
          end
        end

        def write(data, chunk)
          data << chunk.data
          chunk.message.ack
        end

        def stop(data, pull)
          data.close
          pull.stop
        end

        def wait(data, options)
          return unless options.wait?

          data.wait(options.timeout)
          raise DigestMismatchError unless data.valid?
        end
      end
    end
  end
end
