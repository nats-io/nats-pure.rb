# frozen_string_literal: true

module NATS
  class JetStream
    class Consumer
      class Consume < Subscription::Pull
        def handle_message(message)
          push(message)
        end
      end
    end
  end
end
