# frozen_string_literal: true

module NATS
  class JetStream
    class Fetch < Pull
      class Timeout
        attr_reader :pull

        def initialize(pull)
          @pull = pull
        end

        def start
          task.execute
        end

        def stop
          task.cancel
        end

        private

        def task
          @task ||= Concurrent::ScheduledTask.new(timeout) do
            pull.synchronize do
              pull.stop(PullTimeoutError.new)
            end
          end
        end

        def timeout
          pull.config.expires_seconds + 1
        end
      end
    end
  end
end
