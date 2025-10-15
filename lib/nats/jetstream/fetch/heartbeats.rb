# frozen_string_literal: true

module NATS
  class JetStream
    class Fetch < Pull
      class Heartbeats < Pull::Heartbeats
        def reset
          task.reset
        end

        private

        def handle
          pull.synchronize do
            pull.stop(NoHeartbeatError.new)
          end
        end
      end
    end
  end
end
