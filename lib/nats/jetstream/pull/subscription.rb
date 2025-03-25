# frozen_string_literal: true

module NATS
  class JetStream
    class Pull
      class Subscription
        attr_reader :pull, :client, :inbox, :handler

        def initialize(pull)
          @pull = pull
          @client = pull.js.client
          @handler = pull.handler

          @inbox = client.new_inbox
        end

        def start
          @subscription = client.subscribe(inbox) do |message|
            handler.handle(message)
          rescue => error
            error(error)
            raise error
          end
        end

        def drain
          client.send(:drain_sub, @subscription)
        end

        private

        def error(error)
          pull.synchronize do
            pull.drain(error)
          end
        end
      end
    end
  end
end
