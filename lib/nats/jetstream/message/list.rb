# frozen_string_literal: true

module NATS
  class JetStream
    class Message < NATS::Utils::Config
      class List < NATS::Utils::List
        alias stream parent

        def find(params)
          response = js.api.stream.msg.get(stream.subject, params)
          StreamMessage.new(stream, response.data.message)
        end

        private

        def js
          stream.js
        end
      end
    end
  end
end
