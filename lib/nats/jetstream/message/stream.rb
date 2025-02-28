# frozen_string_literal: true

require "base64"

module NATS
  class JetStream
    class StreamMessage < Message
      attr_reader :stream, :js

      string :subject
      hash :header, default: {}
      string :data

      integer :seq
      string :time

      def initialize(stream, message)
        @stream = stream
        @js = stream.js

        super(
          subject: message.subject,
          header: parse_header(message),
          data: Base64.decode64(message.data),
          seq: message.seq,
          time: message.time
        )
      end

      def delete
        js.api.stream.msg.delete(stream.subject, seq: seq).success?
      end

      def inspect
        "@subject=#{subject}, @header=#{header}, @data=#{data}, @seq=#{seq}, @time=#{time}"
      end

      private

      def parse_header(message)
        return unless message.hdrs

        header = Base64.decode64(message.hdrs)
        js.client.send(:process_hdr, header)
      end
    end
  end
end
