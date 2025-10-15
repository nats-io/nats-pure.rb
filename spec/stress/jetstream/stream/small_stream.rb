# frozen_string_literal: true

module NATS
  class Stress
    class JetStream < Stress
      class SmallStream < Stream
        def name
          "small-stream"
        end

        def publish
          10_000.times do |index|
            js.publish(name, Random.bytes(100))

            if index % 1_000 == 0
              puts "Published #{index + 1_000} messages"
            end
          end
        end
      end
    end
  end
end
