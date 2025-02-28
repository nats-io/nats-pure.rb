# frozen_string_literal: true

require_relative "message/status"
require_relative "message/list"

module NATS
  class JetStream
    class Message < NATS::Utils::Config
      class << self
        def build(consumer, message)
          message_type(message).new(consumer, message)
        end

        def message_type(message)
          status = message.header["Status"] if message.header

          case status
          when "100"
            IdleHeartBeatMessage
          when "400"
            BadRequestMessage
          when "404"
            NoMessagesMessage
          when "408"
            RequestTimeout
          when "409"
            message_409_type(message)
          when "503"
            NoRespondersMessage
          else
            ConsumerMessage
          end
        end

        def message_409_type(message)
          description = message.header["Description"]

          case description.downcase
          when /exceeded maxrequestbatch/
            MaxRequestBatchMessage
          when /exceeded maxrequestexpires/
            MaxRequestExpiresMessage
          when /exceeded maxrequestmaxbytes/
            MaxRequestMaxBytesMessage
          when /exceeded maxwaiting/
            MaxWaitingMessage
          when /message size exceeds maxbytes/
            MaxBytesExceeded
          when /batch completed/
            BatchCompletedMessage
          when /consumer deleted/
            ConsumerDeletedMessage # ErrorMessage
          when /leadership change/
            ConsumerLeadershipChangedMessage
          end
        end
      end

      def inspect
        "#<#{self.class} @subject=#{subject}, @header=#{header}, @data=#{data}>"
      end
    end
  end
end

require_relative "message/consumer"
require_relative "message/stream"
