# frozen_string_literal: true

module NATS
  class Stress
    class JetStream < Stress
      class Connection < Stream
        def setup
        end

        def cleanup
        end

        def context
          {
            # "benchstream"
            # "quuz"
            stream: "sources",
            server: "js:js@ev.nats.dev"
          }
        end
      end
    end
  end
end
