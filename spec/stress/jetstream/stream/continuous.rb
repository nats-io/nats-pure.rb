# frozen_string_literal: true

module NATS
  class Stress
    class JetStream < Stress
      class Continuous < Stream
        def name
          "continuous"
        end

        def publish
        end

        def context
          {stream: name, publish: true}
        end
      end
    end
  end
end
