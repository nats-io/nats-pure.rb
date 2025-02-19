# frozen_string_literal: true

require_relative "jetstream/stream"
require_relative "jetstream/consumer"

require_relative "jetstream/api"

module NATS
  class JetStream
    attr_reader :client, :api, :streams, :consumers

    def initialize(client)
      @client = client
      @api = API.new(client)

      @streams = Stream::List.new(self)
      @consumers = Consumer::List.new(self)
    end

    def info
      api.info
    end
  end
end
