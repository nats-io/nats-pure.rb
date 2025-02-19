# frozen_string_literal: true

require_relative "api/dsl"
require_relative "api/group"
require_relative "api/request"
require_relative "api/response-old"

module NATS
  class JetStream
    class API
      extend DSL

      request :info, AccountInfoResponse, subject: false

      group :stream do
        request :create, StreamCreateResponse
        request :update, StreamUpdateResponse
        request :info, StreamInfoResponse
        request :delete, StreamDeleteResponse
        request :purge, StreamPurgeResponse

        request :names, StreamNamesResponse, subject: false
        request :list, StreamInfoResponse, subject: false

        group :msg do
          request :get, StreamMsgGetResponse
          request :delete, StreamMsgDeleteResponse
        end

        request :snapshot, StreamSnapshotResponse
        request :restore, StreamResptoreResponse

        group :peer do
          request :remove, StreamRemovePeerResponse
        end

        group :leader do
          request :stepdown, StreamLeaderStepdownResponse
        end
      end

      group :consumer do
        request :create, ConsumerCreateResponse

        group :durable do
          request :create, ConsumerCreateResponse
        end

        request :delete, ConsumerDeleteResponse
        request :info, ConsumerInfoResponse
        request :list, ConsumerListResponse, subject: false
        request :names, ConsumerNamesResponse, subject: false
      end

      attr_reader :client

      def initialize(client, prefix = nil)
        @client = client
        @prefix = prefix || "$JS.API"
      end

      def subject
        @prefix
      end
    end
  end
end
