# frozen_string_literal: true

module NATS
  class Stress
    class JetStream < Stress
      class Stream
        def setup
          puts "Setting up #{name}..."

          js.streams.create(name: stream)

          publish
        end

        def cleanup
          js.streams.find(name).delete
        rescue
          puts "Stream #{stream} not found"
        end

        def context
          {stream: name}
        end

        private

        def js
          @js ||= client.js
        end

        def client
          @client ||= NATS.connect
        end
      end
    end
  end
end

require_relative "stream/small_stream"
require_relative "stream/large_stream"
require_relative "stream/large_messages"
require_relative "stream/continuous"
require_relative "stream/mixed"
require_relative "stream/connection"
