# frozen_string_literal: true

require "monitor"

module NATS
  class JetStream
    class Subscription
      class Message
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
        end

        attr_reader :consumer, :code, :description

        def initialize(consumer, message)
          @consumer = consumer
          @message = message
        end
      end
    end
  end
end
