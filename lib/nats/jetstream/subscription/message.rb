# frozen_string_literal: true

require "monitor"

module NATS
  class JetStream
    class Subsciption
      class Message
        STATUSES = {
          "100" => ControlMessage,
          "400" => BadRequest,
          "404" => NoMessages,
          "408" => RequestTimeout,
          "409" => PullTerminated,
          "503" => NoResponders
        }.freeze

        #Errors:
        #400 Bad Request
        #409 Consumer Deleted
        #409 Consumer is push based

        #Warnings:
        #409 Exceeded MaxRequestBatch of %d
        #409 Exceeded MaxRequestExpires of %v
        #409 Exceeded MaxRequestMaxBytes of %v
        #409 Exceeded MaxWaiting

        #Not Telegraphed:
        #404 No Messages
        #408 Request Timeout
        #409 Message Size Exceeds MaxBytes

        class << self
          def build(stream, message)
            message.header
          end
        end

        attr_reader

        def initialize(stream, )
        end
      end

      class UserMessage < Message
      end

      class ControlMessage < Message
      end

      class BadRequest < Message
      end

      class NoMessages < Message
      end

      class RequestTimeout < Message
      end

      class PullTerminated < Message
      end

      class NoResponders < Message
      end
    end
  end
end
