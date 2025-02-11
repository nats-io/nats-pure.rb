# frozen_string_literal: true

module NATS
  class JetStream
    class API
      DEFAULT_PREFIX = "$JS".freeze

      request :info, Response

      group :stream do
        request :create, StreamResponse
        request :update, StreamResponse
        request :info, StreamInfoResponse
        request :delete, StreamInfoResponse
        request :purge, StreamInfoResponse

        request :names, StreamResponse, subject: false
        request :list, StreamResponse, subject: false

        group :msg do
          request :get, StreamInfoResponse
          request :delete, StreamInfoResponse
        end

        request :snapshot, Response
        request :restore, Response

        group :peer do
          request :remove, Response
        end

        group :leader do
          request :stepdown, Response
        end
      end

      group :consumer do
        request :create, Response

        group :durable do
          request :create, Response
        end

        request :delete, Response
        request :info, Response
        request :list, Response
        request :names, Response
      end

      def request(subject, options)
      end
    end
  end
end
