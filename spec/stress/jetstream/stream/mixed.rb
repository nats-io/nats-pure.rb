# frozen_string_literal: true

module NATS
  class Stress
    class JetStream < Stress
      class Mixed < Stream
        def name
          "mixed"
        end

        def publish
          10_000.times do |index|
            js.publish(name, Random.bytes(rand * 10_000))

            if index % 1_000 == 0
              puts "Published #{index} messages"
            end
          end
        end

        def context
          {stream: name, publish: true}
        end
      end
    end
  end
end
