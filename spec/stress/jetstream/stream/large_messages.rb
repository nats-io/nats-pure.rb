# frozen_string_literal: true

module NATS
  class Stress
    class JetStream < Stress
      class LargeMessages < Stream
        def name
          "large-messages"
        end

        def publish
          100.times do |index|
            js.publish(stream, Random.bytes(1_000_000))
          end
        end
      end
    end
  end
end
