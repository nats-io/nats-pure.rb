# frozen_string_literal: true

module NATS
  class Stress
    class JetStream < Stress
      class LargeStream < Stream
        def name
          "large-stream"
        end

        def publish
          10_000_000.times do |index|
            js.publish(name, Random.bytes(100))

            if index % 10_000 == 0
              puts "Published #{index} messages"
            end
          end
        end
      end
    end
  end
end
