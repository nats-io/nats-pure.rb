# frozen_string_literal: true

require_relative "fetch/config"
require_relative "fetch/buffer"
require_relative "fetch/heartbeats"
require_relative "fetch/timeout"
require_relative "fetch/handler"

module NATS
  class JetStream
    class Fetch < Pull
      def initialize(consumer, params = {}, &block)
        super(consumer, params)

        @config = Config.new(params)
        @buffer = Buffer.new(self)
        @handler = Handler.new(self, &block)
        @heartbeats = Heartbeats.new(self)
        @monitor = Timeout.new(self)
        @subscription = Pull::Subscription.new(self)
      end

      def wait(timeout = nil)
        synchronize do
          timeout ||= config.expires_seconds + 1
          @closed_cond.wait(timeout)
        end
      end

      def messages
        buffer.messages
      end
    end
  end
end
