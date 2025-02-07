# frozen_string_literal: true

module NATS
  class JetStream
    class Pull
      class Subscription
        attr_reader :js, :inbox, :handler

        def initialize(pull)
          @js = pull.js
          @handler = pull.handler

          @inbox = js.client.new_inbox
        end

        def start
          @subscription = js.client.subscribe(inbox) do |message|
            handler.handle(message)
          rescue => error
            handler.error(error.message)
            raise error
          end
        end

        def drain
          js.client.send(:drain_sub, @subscription)
        end
      end
    end
  end
end
