# frozen_string_literal: true

require "json"

module NATS
  class Message
    class Server < Message
    end

    class Info < Server
      attr_reader :options

      def initialize(params)
        @options = JSON.parse(params["options"])
      rescue JSON::ParserError
        raise NATS::IO::ServerError, "INFO message contains an invalid JSON"
      end
    end

    class Msg < Server
      attr_reader :subject, :sid, :reply_to, :bytes, :payload

      def initialize(params)
        @subject = params["subject"]
        @sid = params["sid"].to_i
        @reply_to = params["reply_to"]
        @bytes = params["bytes"].to_i
      end
    end

    class Hmsg < Msg
      attr_reader :header_bytes, :headers

      alias total_bytes bytes

      def initialize(params)
        super(params)

        @header_bytes = params["header_bytes"].to_i
      end
    end

    class Ok < Server; end

    class Err < Server
      attr_reader :message

      def initialize(params)
        @message = params["message"]
      end
    end
  end
end
