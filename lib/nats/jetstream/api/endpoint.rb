# frozen_string_literal: true

module NATS
  class JetStream
    class API
      class Endpoint
        attr_reader :name, :request, :response, :client

        def initialize(parent:, name:, request:, response:, client:)
          @name = name
          @client = client
          @request = request
          @response = response
          @subject = "#{parent.subject}.#{name.upcase}"
        end

        def call(subject, data = nil, params = {})
          subject = [@subject, subject].compact.join(".")
          data = request.new(data).to_json

          message = begin
            client.request(subject, data, **params)
          rescue NATS::IO::NoRespondersError
            raise JetStream::ServiceUnavailableError
          end

          response.build(message)
        end
      end
    end
  end
end
