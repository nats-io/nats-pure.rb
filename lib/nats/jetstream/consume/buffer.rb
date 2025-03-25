# frozen_string_literal: true

module NATS
  class JetStream
    class Consume < Pull
      class Buffer < Pull::Buffer
        attr_reader :messages_fetched, :messages_pending, :bytes_pending

        def initialize(pull)
          super

          @messages_fetched = 0
        end

        def reset
          @messages_pending = config.max_messages
          @bytes_pending = config.max_bytes
        end

        def consumed(message)
          @messages_fetched += 1
          @messages_pending -= 1

          if max_bytes?
            @bytes_pending -= message.bytesize
          end
        end

        def depleting?
          if max_messages?
            messages_depleting?
          else
            messages_depleting? || bytes_depleting?
          end
        end

        def refill
          @messages_pending += config.max_messages

          if max_bytes?
            @bytes_pending += config.max_bytes
          end
        end

        def trim(message)
          @messages_pending -= message.pending_messages
          @messages_pending = 0 if @messages_pending < 0

          if max_bytes?
            @bytes_pending -= message.pending_bytes
            @bytes_pending = 0 if @bytes_pending < 0
          end
        end

        private

        def messages_depleting?
          @messages_pending <= config.threshold_messages
        end

        def bytes_depleting?
          @bytes_pending <= config.threshold_bytes
        end
      end
    end
  end
end
