# frozen_string_literal: true

module NATS
  class JetStream
    class Pull
      class Handler
        attr_reader :pull, :block, :processing

        def initialize(pull, &block)
          @pull = pull
          @block = block
          @processing = 0
        end

        def handle(message)
          start
          process(message)
        ensure
          finish
        end

        def drained?
          pull.draining? && processing <= 0
        end

        private

        def start
          synchronize { @processing += 1 }
        end

        def finish
          synchronize do
            @processing -= 1
            pull.closed! if drained?
          end
        end

        def process(message)
          message = build(message)

          case message
          when ConsumerMessage
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

        %i[monitor buffer].each do |method|
          define_method method do
            pull.send(method)
          end
        end
      end
    end
  end
end
