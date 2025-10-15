# frozen_string_literal: true

module NATS
  class JetStream
    class Pull
      class Handler
        attr_reader :pull, :block

        def initialize(pull, &block)
          @pull = pull
          @block = block
        end

        def handle(message)
          process(message)
        ensure
          finish
        end

        def drained?
          pull.draining? && pull.subscription.empty?
        end

        private

        def finish
          synchronize do
            pull.closed! if drained?
          end
        end

        def process(message)
          message = build(message)

          case message
          when Message
            consumer(message)
          when IdleHeartbeatMessage
            heartbeat(message)
          when WarningMessage
            warning(message)
          else
            error(message)
          end
        end

        def build(message)
          Message.build(pull.consumer, message)
        end

        def synchronize(&block)
          pull.synchronize(&block)
        end

        %i[heartbeats buffer].each do |method|
          define_method method do
            pull.send(method)
          end
        end
      end
    end
  end
end
