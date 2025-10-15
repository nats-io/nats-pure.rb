# frozen_string_literal: true

require "open-uri"

require_relative "test"

require_relative "object_store/default_bucket"
require_relative "object_store/custom_bucket"
require_relative "object_store/put_object"
require_relative "object_store/get_object"
require_relative "object_store/put_link"
require_relative "object_store/get_link"
require_relative "object_store/update_metadata"
require_relative "object_store/watch"
require_relative "object_store/watch_updates"

module NATS
  class Compability
    class ObjectStore
      TESTS = [
        DefaultBucket,
        CustomBucket,
        PutObject,
        GetObject,
        PutLink,
        GetLink,
        UpdateMetadata,
        Watch,
        WatchUpdates
      ]

      attr_reader :context

      def initialize
        @context = NATS.connect.object_store
      end

      def run
        TESTS.each do |test|
          test.new(context).run
        end
      end

      def stop
        context.client.close
      end
    end
  end
end
