# frozen_string_literal: true

module NATS
  class JetStream
    class Consume < Pull
      class Heartbeats < Pull::Heartbeats
        def reset
          if task.pending?
            task.reset
          else
            stop
            set
            start
          end
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
