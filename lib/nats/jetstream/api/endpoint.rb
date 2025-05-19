# frozen_string_literal: true

module NATS
  class JetStream
    class API
      class Endpoint
        attr_reader :name, :request, :response, :client

        def initialize(parent:, name:, request:, response:)
          @name = name
          @request = request
          @response = response
          @client = parent.client
          @subject = "#{parent.subject}.#{name.upcase}"
        end

        def call(subject, data = nil, params = {})
          subject = [@subject, subject].compact.join(".")
          payload = request.new(data).to_json

          if response
            request_message(subject, payload, params)
          else
            publish_message(subject, payload, params)
          end
        end

        private

        def request_message(subject, payload, params)
          message = begin
            client.request(subject, payload, **params)
          rescue NATS::IO::NoRespondersError
            raise JetStream::ServiceUnavailableError
          end

          response.build(message)
        end

        def publish_message(subject, payload, params)
          reply_to = params.delete(:reply_to)
          client.publish(subject, payload, reply_to, **params)
        end
      end
    end
  end
end
