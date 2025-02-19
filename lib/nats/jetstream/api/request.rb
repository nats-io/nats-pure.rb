# frozen_string_literal: true

module NATS
  class JetStream
    class API
      class Request
        attr_reader :name, :response, :client

        def initialize(name:, parent:, response:, client:)
          @name = name
          @response = response
          @client = client
          @subject = "#{parent.subject}.#{name.upcase}"
        end

        def request(subject, data = nil, params = {})
          subject = [@subject, subject].compact.join(".")

          message = begin
            client.request(subject, data.to_json, **params)
          rescue NATS::IO::NoRespondersError
            #raise JetStream::ServiceUnavailableError
          end

          response.build(message)
        end
      end
    end
  end
end
