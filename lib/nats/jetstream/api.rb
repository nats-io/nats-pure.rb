# frozen_string_literal: true

require_relative "api/dsl"
require_relative "api/group"
require_relative "api/endpoint"
require_relative "api/request"
require_relative "api/response"
require_relative "api/iterator"

module NATS
  class JetStream
    class API
      extend DSL

      endpoint :info, response: AccountInfoResponse, subject: false

      group :stream do
        endpoint :create, request: StreamCreateRequest, response: StreamCreateResponse
        endpoint :update, request: StreamUpdateRequest, response: StreamUpdateResponse
        endpoint :info, request: StreamInfoRequest, response: StreamInfoResponse
        endpoint :delete, response: StreamDeleteResponse
        endpoint :purge, request: StreamPurgeRequest, response: StreamPurgeResponse

        endpoint :list, request: StreamListRequest, response: StreamListResponse, subject: false
        endpoint :names, request: StreamNamesRequest, response: StreamNamesResponse, subject: false

        group :msg do
          endpoint :get, request: StreamMsgGetRequest, response: StreamMsgGetResponse
          endpoint :delete, response: StreamMsgDeleteResponse
        end

        endpoint :snapshot, request: StreamSnapshotRequest, response: StreamSnapshotResponse
        endpoint :restore, request: StreamRestoreRequest, response: StreamRestoreResponse

        group :peer do
          endpoint :remove, request: StreamRemovePeerRequest, response: StreamRemovePeerResponse
        end

        group :leader do
          endpoint :stepdown, response: StreamLeaderStepdownResponse
        end
      end

      group :consumer do
        endpoint :create, request: ConsumerCreateRequest, response: ConsumerCreateResponse

        group :durable do
          endpoint :create, response: ConsumerCreateResponse
        end

        endpoint :delete, response: ConsumerDeleteResponse
        endpoint :info, response: ConsumerInfoResponse

        endpoint :list, request: ConsumerListRequest, response: ConsumerListResponse
        endpoint :names, request: ConsumerNamesRequest, response: ConsumerNamesResponse

        group :msg do
          endpoint :next, request: ConsumerGetNextRequest, response: false
        end
      end

      attr_reader :jetstream, :client

      alias js jetstream

      def initialize(jetstream, prefix = nil)
        @jetstream = jetstream
        @client = jetstream.client
        @prefix = prefix || "$JS.API"
      end

      def subject
        @prefix
      end
    end
  end
end
