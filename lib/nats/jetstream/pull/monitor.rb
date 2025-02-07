# frozen_string_literal: true

module NATS
  class JetStream
    class Pull
      class Monitor
        attr_reader :pull, :config, :heartbeats

        def initialize(pull)
          @pull = pull
          @config = pull.config

          set_heartbeats
        end

        private

        def set_heartbeats
          @heartbeats = Concurrent::ScheduledTask.new(2 * config.idle_heartbeat_seconds) do
            handle_no_heartbeats
          end
        end

        def synchronize(&block)
          pull.synchronize(&block)
        end
      end
    end
  end
end
