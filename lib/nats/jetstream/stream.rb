# frozen_string_literal: true

module NATS
  class JetStream
    class Stream
      def initialize(config)
        @config = Config.new(config)
      end
    end
  end
end
