# frozen_string_literal: true

require "nats/message/client"
require "nats/message/server"

module NATS
  class Message
    def initialize(params)
    end

    class Ping < Message; end

    class Pong < Message; end
  end
end
