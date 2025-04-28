# frozen_string_literal: true

module NATS
  class JetStream
    class Consume < Pull
      class Heartbeats < Pull::Heartbeats
        def reset
          case task.state
          when :pending
            task.reset
          when :processing
            restart
          end
        end

        def restart
          stop
          set
          start
        end

        private

        def handle
          pull.synchronize do
            pull.request_messages
            pull.buffer.reset

            reset
          end
        end
      end
    end
  end
end
