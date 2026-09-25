# frozen_string_literal: true

begin
  require "websocket"
rescue LoadError
  raise LoadError, "Please add `websocket` gem to your Gemfile to connect to NATS via WebSocket."
end

module NATS
  module IO
    # WebSocket to connect to NATS via WebSocket and automatically decode and encode frames.

    # @see https://docs.nats.io/running-a-nats-service/configuration/websocket

    class WebSocket < Socket
      class HandshakeError < RuntimeError; end

      attr_accessor :socket

      def initialize(options = {})
        super
      end

      def connect
        super

        setup_tls! if @uri.scheme == "wss" # WebSocket connection must be made over TLS from the beginning

        @handshake = ::WebSocket::Handshake::Client.new url: @uri.to_s
        @frame = ::WebSocket::Frame::Incoming::Client.new
        @handshaked = false

        @socket.write @handshake.to_s

        until @handshaked
          @handshake << method(:read).super_method.call(MAX_SOCKET_READ_BYTES)
          if @handshake.finished?
            @handshaked = true
          end
        end
      end

      def setup_tls!
        return if @socket.is_a? OpenSSL::SSL::SSLSocket

        super
      end

      def read(max_bytes = MAX_SOCKET_READ_BYTES, deadline = nil)
        # Hand over what read_line decoded beyond its last line first,
        # otherwise those bytes are lost once the read loop takes over.
        if @line_buf && !@line_buf.empty?
          return @line_buf.slice!(0, @line_buf.bytesize)
        end

        read_frames(max_bytes, deadline)
      end

      def read_line(deadline = nil)
        @line_buf ||= +""
        loop do
          if (idx = @line_buf =~ /\r?\n/)
            return @line_buf.slice!(0, idx + Regexp.last_match(0).length)
          end

          # Pull more data from the wire; never from @line_buf itself,
          # or a partial line would be fed back forever.
          data = read_frames(MAX_SOCKET_READ_BYTES, deadline)
          return nil unless data
          @line_buf << data
        end
      end

      def write(data, deadline = nil)
        raise HandshakeError, "Attempted to write to socket while WebSocket handshake is in progress" unless @handshaked

        frame = ::WebSocket::Frame::Outgoing::Client.new(data: data, type: :binary, version: @handshake.version)
        super(frame.to_s)
      end

      private

      # Reads from the socket and returns the payloads of all complete
      # frames decoded so far.
      def read_frames(max_bytes, deadline)
        data = Socket.instance_method(:read).bind_call(self, max_bytes, deadline)
        @frame << data
        [].tap do |parts|
          while (msg = @frame.next)
            payload = msg.respond_to?(:data) ? msg.data : msg
            parts << payload if payload
          end
        end.join
      end
    end
  end
end
