# frozen_string_literal: true

require "monitor"

module NATS
  class JetStream
    class PullSubscription
      class Response
        HEADERS = {
          "100" => ControlMessage,
          "400" => BadRequest,
          "404" => NoMessages,
          "408" => RequestTimeout,
          "409" => MaxBytesExceeded,
          "503" => NoResponders
        }.freeze

        class << self
          def build(stream, message)
            message.header
          end
        end
      end

      class ControlMessage < Response
      end

      class BadRequest < Response
      end

      class NomEssages < Response
      end

      class RequestTimeout < Response
      end

      class MaxBytesExceeded < Response
      end

      class NoResponders < Response
      end
    end
  end
end
