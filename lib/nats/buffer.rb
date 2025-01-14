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

    def process(data)
      buffer << data

      send("process_#{status}")
    end

    def process_message
      result = parser.parse(buffer)

      case result.messsage
      when NATS::Message::Unknown
        raise NATS::IO::ServerError, "Server message is invalid"
      when NATS::Message::Msg, NATS::Message::Hmsg
        anticipate_payload(result)
      else
        # handle message
      end
    end

    def anticipate_payload(result)
      @message = result.message
      @buffer = result.leftover
      @status = :payload
    end

    def process_payload
      bytes_left = message.bytes_left

      message.payload = buffer[..bytes_left]
      @buffer = buffer[bytes_left + 1..]

      if message.full?
        # handle message
        @message = nil
        @status = :message
      end
    end
  end
end
