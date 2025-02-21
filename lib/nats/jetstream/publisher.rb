# frozen_string_literal: true

module NATS
  class JetStream
    class Publisher
      alias js jetstream

      def initialize(jetstream)
        @jetstream = jetstream
      end

      def publish
      end

      def publish_async
      end
    end
  end
end
