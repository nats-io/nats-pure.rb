# frozen_string_literal: true

require_relative "message/status"
require_relative "message/list"

module NATS
  class JetStream
    class Message < NATS::Utils::Config
      class << self
        def build(consumer, message)
          if message.header && message.header["Status"]
            StatusMessage.new(consumer, message)
          else
            ConsumerMessage.new(consumer, message)
          end
        end
      end

      def inspect
        "@subject=#{subject}, @header=#{header}, @data=#{data}"
      end
    end
  end
end

require_relative "message/consumer"
require_relative "message/stream"
