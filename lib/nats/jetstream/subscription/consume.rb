# frozen_string_literal: true

module NATS
  class JetStream
    class Subscription
      class Consume < Pull
        def handle_message(message)
          push(message)
        end
      end
    end
  end
end
