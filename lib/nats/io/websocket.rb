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
        data = super
        @frame << data
        result = []
        while (msg = @frame.next)
          result << msg
        end
        result.join
      end

      def read_line(deadline = nil)
        data = super
        @frame << data
        result = []
        while (msg = @frame.next)
          result << msg
        end
        result.join
      end

      def write(data, deadline = nil)
        raise HandshakeError, "Attempted to write to socket while WebSocket handshake is in progress" unless @handshaked

        frame = ::WebSocket::Frame::Outgoing::Client.new(data: data, type: :binary, version: @handshake.version)
        super(frame.to_s)
      end
    end
  end
end
