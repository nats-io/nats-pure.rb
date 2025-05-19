# frozen_string_literal: true

module NATS
  class JetStream
    class Pull
      class Heartbeats
        attr_reader :pull, :task

        def initialize(pull)
          @pull = pull
          set
        end

        def start
          task.execute
        end

        def stop
          task.cancel
        end

        private

        def set
          @task = Concurrent::ScheduledTask.new(heartbeats) do
            handle
          end
        end

        def heartbeats
          2 * pull.config.idle_heartbeat_seconds
        end
      end
    end
  end
end
