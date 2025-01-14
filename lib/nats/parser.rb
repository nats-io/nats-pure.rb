# frozen_string_literal: true

module NATS
  class Parser
    REGEX = {
      NATS::Message::Info => /\AINFO\s+(?<options>[^\r\n]+)\r\n/i,
      NATS::Message::Msg => /\AMSG\s+(?<subject>[^\s]+)\s+(?<sid>[^\s]+)\s+((?<reply_to>[^\s]+)[^\S\r\n]+)?(?<bytes>\d+)\r\n/i,
      NATS::Message::Hmsg => /\AHMSG\s+(?<subject>[^\s]+)\s+(?<sid>[^\s]+)\s+((?<reply_to>[^\s]+)[^\S\r\n]+)?(?<header_bytes>[\d]+)\s+(?<bytes>\d+)\r\n/i,
      NATS::Message::Ping => /\APING\s*\r\n/i,
      NATS::Message::Pong => /\APONG\s*\r\n/i,
      NATS::Message::Ok => /\A\+OK\s*\r\n/i,
      NATS::Message::Err => /\A-ERR\s+('(?<message>.+)')?\r\n/,
      NATS::Message::Unknown => /(?m)\A(?<data>.*)\z/
    }.freeze

    def parse(data)
      REGEX.find do |type, regex|
        match = data.match(regex)
        break Result.new(type, match) if match
      end
    end

    class Result
      attr_reader :message, :leftover

      def initialize(type, match)
        @message = type.new(match.named_captures)
        @leftover = match.post_match
      end
    end
  end
end
