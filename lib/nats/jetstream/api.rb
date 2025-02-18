# frozen_string_literal: true

require_relative "api/dsl"
require_relative "api/group"
require_relative "api/request"
require_relative "api/response"

module NATS
  class JetStream
    class API
      extend DSL

      request :info, StreamInfo, subject: false

      group :stream do
        request :create, StreamInfo
        request :update, StreamInfo
        request :info, StreamInfo
        request :delete, StreamInfo
        request :purge, StreamInfo

        request :names, StreamInfo, subject: false
        request :list, StreamInfo, subject: false

        group :msg do
          request :get, StreamInfo
          request :delete, StreamInfo
        end

        request :snapshot, StreamInfo
        request :restore, StreamInfo

        group :peer do
          request :remove, StreamInfo
        end

        group :leader do
          request :stepdown, StreamInfo
        end
      end

      group :consumer do
        request :create, ConsumerInfo

        group :durable do
          request :create, ConsumerInfo
        end

        request :delete, ConsumerInfo
        request :info, ConsumerInfo
        request :list, ConsumerInfo
        request :names, ConsumerInfo
      end

      attr_reader :client

      def initialize(client)
        @client = client
      end

      def subject
        "$JS.API"
      end
    end
  end
end
