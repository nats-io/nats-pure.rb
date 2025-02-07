# frozen_string_literal: true

module NATS
  class JetStream
    class Consumer
      attr_reader :stream, :config

      def initialize(config)
        @config = Config.new(config)
      end
    end
  end
end
