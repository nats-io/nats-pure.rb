# frozen_string_literal: true

module NATS
  class JetStream
    class Stream
      def initialize(config)
        @config = Config.new(config)
        @stream = Manager.add_stream(config)
      end

      def update(config)
        @stream = Manager.update_stream(config)
      end

      def delete
        Manager.delete_stream(config)
      end

      def publish(message, options)
      end

      def messages
      end

      def info
        Manager.stream_info(self)
      end

      def purge(options)
      end
    end
  end
end
