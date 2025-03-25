# frozen_string_literal: true

module NATS
  class JetStream
    class Pull
      class Config < NATS::Utils::Config
        integer :expires, min: 1.to_nsec, default: 30.to_nsec
        integer :idle_heartbeat, min: 0.5.to_nsec, max: 30.to_nsec

        integer :max_messages, min: 1
        integer :max_bytes, min: 0

        alias_method :batch, :max_messages

        def initialize(values)
          super

          if idle_heartbeat.nil?
            set_idle_heartbeat
          end

          if idle_heartbeat * 2 > expires
            raise InvalidIdleHeartbeatError
          end
        end

        def expires_seconds
          expires.from_nsec
        end

        def idle_heartbeat_seconds
          idle_heartbeat.from_nsec
        end

        private

        def set_idle_heartbeat
          return if idle_heartbeat

          @idle_heartbeat =
            if ordered? && expires >= 10.to_nsec
              5.to_nsec
            else
              expires / 2
            end
        end
      end
    end
  end
end
