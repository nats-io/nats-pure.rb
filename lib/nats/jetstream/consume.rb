# frozen_string_literal: true

require_relative "consume/config"
require_relative "consume/buffer"
require_relative "consume/heartbeats"
require_relative "consume/connection"
require_relative "consume/handler"

module NATS
  class JetStream
    class Consume < Pull
      def initialize(consumer, params = {}, &block)
        super

        @config = Config.new(params)
        @buffer = Buffer.new(self)
        @handler = Handler.new(self, &block)
        @heartbeats = Heartbeats.new(self)
        @monitor = Connection.new(self)
        @subscription = Pull::Subscription.new(self)
      end

      def wait(timeout = nil)
        synchronize do
          @closed_cond.wait(timeout)
        end
      end
    end
  end
end
