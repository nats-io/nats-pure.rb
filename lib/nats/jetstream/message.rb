# frozen_string_literal: true

require_relative "message/status"
require_relative "message/ack"
require_relative "message/metadata"

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
            IdleHeartbeatMessage
          when "400"
            BadRequestMessage
          when "404"
            NoMessagesMessage
          when "408"
            RequestTimeoutMessage
          when "409"
            message_409_type(message)
          when "503"
            NoRespondersMessage
          else
            Message
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
            MaxBytesExceededMessage
          when /batch completed/
            BatchCompletedMessage
          when /consumer deleted/
            ConsumerDeletedMessage
          when /leadership change/
            ConsumerLeadershipChangedMessage
          end
        end
      end

      attr_reader :stream, :metadata

      string :subject
      hash :header, default: {}
      string :raw_header
      string :data
      string :reply

      def initialize(consumer, message)
        @stream = consumer.stream

        super(
          subject: message.subject,
          header: message.header,
          raw_header: message.raw_header,
          data: message.data,
          reply: message.reply
        )

        @ack = Ack.new(self)
        @metadata = Metadata.new(reply)
      end

      def acked?
        @ack.acked?
      end

      def ack(params = {})
        @ack.ack(params)
      end

      def nack(params = {})
        @ack.nack(params)
      end

      def term(params = {})
        @ack.term(params)
      end

      def in_progress(params = {})
        @ack.in_progress(params)
      end

      def delete
        js.api.stream.msg.delete(stream.subject, seq: metadata.sequence).success?
      end

      def bytesize
        [subject, raw_header, data, reply].compact.map(&:bytesize).sum
      end

      def inspect
        "#<#{self.class} @subject=#{subject}, @header=#{header}, @data=#{data}>"
      end
      alias_method :to_s, :inspect

      def to_error
        PullMessageError.new(self)
      end
    end
  end
end
