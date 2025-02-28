# frozen_string_literal: true

module NATS
  class JetStream
    class Subscription
      class Messages
        attr_reader :pull, :config, :list

        def initialize(pull)
          @pull = pull
          @config = pull.config

          reset
        end

        def reset
          @list = []

          @messages_fetched = 0
          @bytes_fetched = 0

          @messages_pending = 0
          @bytes_pending = 0
        end

        def fetched(message)
          @list << message

          @messages_fetched += 1
          @bytes_fetched = message.bytesize
        end

        def consumed(message)
          @messages_pending -= 1
          @bytes_pending = message.bytesize
        end

        def full?
          if config.max_messages
            @messages_fetched == config.max_messages
          else 
            @bytes_fetched >= config.max_bytes
          end
        end

        def empty?
          if config.max_messages
            @messages_pending == 0
          else 
            @bytes_pending <= 0
          end
        end
      end
    end
  end
end
