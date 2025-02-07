# frozen_string_literal: true

module NATS
  class JetStream
    class Fetch < Pull
      class Buffer < Pull::Buffer
        attr_reader :messages, :messages_fetched, :bytes_fetched

        def reset
          @messages = []

          @messages_fetched = 0
          @bytes_fetched = 0
        end

        def fetched(message)
          @messages << message

          @messages_fetched += 1
          @bytes_fetched += message.bytesize
        end

        def full?
          if max_messages?
            @messages_fetched >= config.max_messages
          else
            @bytes_fetched >= config.max_bytes
          end
        end
      end
    end
  end
end
