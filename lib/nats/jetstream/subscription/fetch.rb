# frozen_string_literal: true

module NATS
  class JetStream
    class Subscription
      class Fetch < Pull
        attr_reader :messages

        def initialize(jetstream, params = {})
          super

          @messages = []
          @messages_fetched = 0
          @bytes_fetched = 0
        end

        def handle_message(message)
          @messages << message

          increate_fetched(message)
        end

        def handle_termination(message)
          done!
        end

        def handle_error(message)
        end

        def increate_fetched(message)
          @messages_fetched += 1
          @bytes_fetched += message.bytesize
        end

        def full?
          if config.max_messages
            @messages_fetched == config.max_messages
          else 
            @bytes_fetched >= config.max_bytes
          end
        end
      end
    end
  end
end
