# frozen_string_literal: true

module NATS
  class Buffer
    attr_reader :buffer, :status, :parser, :message

    def initialize
      @buffer = ""
      @message = nil
      @status = :message

      @parser = NATS::Parser.new
    end

    def buffer(data)
      buffer << data

      send("process_#{status}")
    end

    def process_message
      result = parser.parse(buffer)

      case result.messsage
      when NATS::Message::Msg, NATS::Message::Hmsg
        buffer_payload
      when NilClass
        raise 
      else
        # handle message
      end
    end

    def buffer_payload
      @message = result.message
      @buffer = result.leftover
      @status = :payload
    end

    def process_payload
      message.payload = buffer

      if message.full?
        @message = nil
        @status = :message
      end
    end
  end
end
