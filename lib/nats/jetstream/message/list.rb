# frozen_string_literal: true

module NATS
  class JetStream
    class Message
      class List < NATS::Utils::List
        alias stream parent

        def find(params)
          response = js.api.stream.msg.get(params)
          Message.new(stream, response.data)
        end

        private

        def js
          stream.js
        end
      end
    end
  end
end
