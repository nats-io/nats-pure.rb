# frozen_string_literal: true

module NATS
  class JetStream
    class Fetch < Pull
      class Config < Pull::Config
        def initialize(values)
          super

          if max_messages
            @max_bytes = nil
          elsif max_bytes
            @max_messages = nil
          else
            @max_messages = 100
          end
        end
      end
    end
  end
end
