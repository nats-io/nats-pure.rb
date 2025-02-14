# frozen_string_literal: true

module NATS
  class JetStream
    class API
      class Request
        def initialize(name:, group:, response:)
          @name = name
          @group = group
          @response = response
          @subject = "#{group.subject}.#{name}"
        end

        def request(client:, subject:, data:, params:)
          subject = [@subject, subject].compact.join(".")

          message = begin
            client.request(subject, data.to_json, **params)
          rescue NATS::IO::NoRespondersError
            raise JetStream::ServiceUnavailableError
          end

          data = JSON.parse(message.data, symbolize_names: true)
          raise data[:error] if data[:error]

          #response.new(data)
          data
        end
      end
    end
  end
end
