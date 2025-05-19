# frozen_string_literal: true

module NATS
  class JetStream
    class Pull
      class Buffer
        attr_reader :config

        def initialize(pull)
          @config = pull.config

          reset
        end

        private

        def max_messages?
          !config.max_bytes
        end

        def max_bytes?
          !!config.max_bytes
        end
      end
    end
  end
end
