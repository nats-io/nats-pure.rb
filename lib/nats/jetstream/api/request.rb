# frozen_string_literal: true

module NATS
  class JetStream
    class API
      class Request
        def initialize(client:, group:, subject:, response:)
          @client = client
          @name = subject
          @group = group
          @response = response
          @subject = "#{group.subject}.#{subject}"
        end

        def request(subject, data, params)
          message = begin
            client.request(subject, data.to_json, **params)
          rescue NATS::IO::NoRespondersError
            #raise JetStream::Error::ServiceUnavailable
          end
        end


        def api_request(req_subject, req = "", params = {})
          params[:timeout] ||= @opts[:timeout]
          msg = begin
            @nc.request(req_subject, req, **params)
          rescue NATS::IO::NoRespondersError
            raise JetStream::Error::ServiceUnavailable
          end

          result = if params[:direct]
            msg
          else
            JSON.parse(msg.data, symbolize_names: true)
          end
          if result.is_a?(Hash) && result[:error]
            raise JS.from_error(result[:error])
          end

          result
        end
      end
    end
  end
end
