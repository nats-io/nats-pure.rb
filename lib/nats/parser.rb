# frozen_string_literal: true

module NATS
  class Parser
    class Result
      attr_reader :message, :leftover

      def initialize(message:, leftover:)
        @message = message
        @leftover = leftover
      end
    end

    REGEX = {
      NATS::Message::Info => /\AINFO\s+(?<options>[^\r\n]+)\r\n/i,
      NATS::Message::Msg => /\AMSG\s+(?<subject>[^\s]+)\s+(?<sid>[^\s]+)\s+((?<reply_to>[^\s]+)[^\S\r\n]+)?(?<bytes>\d+)\r\n/i,
      NATS::Message::Hmsg => /\AHMSG\s+(?<subject>[^\s]+)\s+(?<sid>[^\s]+)\s+((?<reply_to>[^\s]+)[^\S\r\n]+)?(?<header_bytes>[\d]+)\s+(?<bytes>\d+)\r\n/i,
      NATS::Message::Ping => /\APING\s*\r\n/i,
      NATS::Message::Pong => /\APONG\s*\r\n/i,
      NATS::Message::Ok => /\A\+OK\s*\r\n/i,
      NATS::Message::Err => /\A-ERR\s+('(?<message>.+)')?\r\n/
    }.freeze

    def parse(data)
      REGEX.find do |type, regex|
        match = data.match(regex)
        break result(type, match) if match
      end
    end

    def result(type, match)
      Result.new(
        message: type.new(match.named_captures)
        leftover: $'
      )
    end
  end
end
