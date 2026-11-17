# frozen_string_literal: true

require "json"
require "openssl"
require "socket"

# A NATS server for the TLS and discovery specs. It listens on a free port
# of host, sends INFO, upgrades the connection to TLS when it has a
# context (after INFO, or first), or speaks WebSocket, answers PING with
# PONG and records the CONNECT of every client, with the server name the
# client sent in the handshake (SNI) as "sni". It also records what
# clients send in plaintext after a TLS handshake that failed. As
# nats-server 2.12 and later do, it writes an INFO right after the PONG to
# the first PING, in the same write.
class FakeNatsServer
  CERTS = File.expand_path("../configs/certs", __dir__)

  # A server context with a certificate and key under spec/configs/certs.
  def self.tls_context(cert, key)
    ctx = OpenSSL::SSL::SSLContext.new
    ctx.cert = OpenSSL::X509::Certificate.new(File.read(File.join(CERTS, cert)))
    ctx.key = OpenSSL::PKey.read(File.read(File.join(CERTS, key)))
    ctx
  end

  attr_reader :port

  # tls: the server's SSLContext, or nil for a server without TLS. later:
  # how the connections after the first are served: as the first (nil),
  # with another SSLContext, or with nothing sent at all (:silent). host:
  # the address it listens on.
  # info: INFO fields that are added or replace the defaults.
  # refuse: answers CONNECT with an authorization error and closes the
  # connection.
  # before_tls: bytes written with INFO, before the TLS handshake.
  # tls_first: the TLS handshake comes before INFO.
  # websocket: the client connects over WebSocket, with TLS (wss://) when
  # the server has a context.
  def initialize(tls: nil, later: nil, host: "127.0.0.1", info: {}, refuse: false, before_tls: nil, tls_first: false,
    websocket: false)
    @tls = tls
    @later = later || tls
    @info = info
    @refuse = refuse
    @before_tls = before_tls
    @tls_first = tls_first
    @websocket = websocket
    @mutex = Mutex.new
    @cond = ConditionVariable.new
    @connects = []
    @accepted = 0
    @closed = 0
    @plaintext = +""
    @server_names = {}
    @clients = []
    # jruby-openssl before 0.19.0 does not call servername_cb, so no SNI is
    # seen there.
    @tls&.servername_cb = proc do |ssl, name|
      @mutex.synchronize { @server_names[ssl] = name }
      nil
    end
    @server = TCPServer.new(host, 0)
    @port = @server.addr[1]
    @thread = Thread.new { accept_loop }
  end

  # The number of connections accepted so far.
  def accepted
    @mutex.synchronize { @accepted }
  end

  # The next CONNECT a client sent, or nil when none comes within timeout
  # seconds.
  def next_connect(timeout = 5)
    @mutex.synchronize { @connects.shift } if wait_for(timeout) { @connects.any? }
  end

  # What clients sent in plaintext: on the connections served with nothing
  # sent, and after a TLS handshake that failed.
  def plaintext
    @mutex.synchronize { @plaintext.dup }
  end

  # Waits up to timeout seconds until count connections were accepted.
  def wait_for_accepted(count, timeout = 5)
    wait_for(timeout) { @accepted >= count }
  end

  # Waits up to timeout seconds until the clients closed every connection.
  def wait_for_all_closed(timeout = 5)
    wait_for(timeout) { @closed >= @accepted }
  end

  # Closes the connections accepted so far, as a server that goes away
  # does.
  def drop_clients
    @mutex.synchronize { @clients.each { |c| close_quietly(c) } }
  end

  def shutdown
    @server.close
    drop_clients
    @thread.join(1)
  end

  private

  def wait_for(timeout)
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + timeout
    @mutex.synchronize do
      until yield
        left = deadline - Process.clock_gettime(Process::CLOCK_MONOTONIC)
        return false if left <= 0

        @cond.wait(@mutex, left)
      end
      true
    end
  end

  def accept_loop
    loop do
      sock = @server.accept
      tls = @mutex.synchronize do
        @clients << sock
        @accepted += 1
        @cond.broadcast
        (@accepted == 1) ? @tls : @later
      end
      Thread.new(sock, tls) { |s, t| serve(s, t) }
    end
  rescue IOError, SystemCallError
    # The server socket was closed.
  end

  def serve(sock, tls)
    io = sock
    return record_plaintext(sock) if tls == :silent

    if @tls_first || @websocket
      io = ssl = upgrade(sock, tls) if tls
      io = WebSocketConnection.new(io) if @websocket
      io.write(info_line)
    else
      io.write(info_line + @before_tls.to_s)
      if tls
        begin
          io = ssl = upgrade(sock, tls)
        rescue OpenSSL::SSL::SSLError
          return record_plaintext(sock)
        end
      end
    end

    pings = 0
    while (line = io.gets)
      case line
      when /\ACONNECT (.*)\r\n\z/
        connect = JSON.parse($1)
        @mutex.synchronize do
          @connects << connect.merge("sni" => @server_names.delete(ssl))
          @cond.broadcast
        end
        if @refuse
          io.write("-ERR 'Authorization Violation'\r\n")
          break
        end
      when "PING\r\n"
        pings += 1
        io.write((pings == 1) ? "PONG\r\n#{info_after_first_pong}" : "PONG\r\n")
      end
    end
  rescue IOError, SystemCallError, OpenSSL::SSL::SSLError
    # The client went away or did not complete the handshake.
  ensure
    close_quietly(io)
    @mutex.synchronize do
      @closed += 1
      @cond.broadcast
    end
  end

  # Records what the client sends until it closes the connection.
  def record_plaintext(sock)
    loop do
      data = sock.readpartial(4096)
      @mutex.synchronize { @plaintext << data }
    end
  end

  def upgrade(sock, tls)
    ssl = OpenSSL::SSL::SSLSocket.new(sock, tls)
    ssl.sync_close = true
    ssl.accept
    ssl
  end

  def info
    {server_id: "FAKE", version: "2.14.0", proto: 1, headers: true, max_payload: 1_048_576, tls_required: !@tls.nil?}.merge(@info)
  end

  def info_line
    "INFO #{info.to_json}\r\n"
  end

  def info_after_first_pong
    (Gem::Version.new(info[:version]) >= Gem::Version.new("2.12.0")) ? info_line : ""
  end

  def close_quietly(io)
    io.close
  rescue IOError, SystemCallError, OpenSSL::SSL::SSLError
    # Already closed.
  end

  # The server side of a WebSocket connection, with the gets and write the
  # server loop uses.
  class WebSocketConnection
    def initialize(io)
      require "websocket"
      @io = io
      handshake = ::WebSocket::Handshake::Server.new
      handshake << io.readpartial(4096) until handshake.finished?
      io.write(handshake.to_s)
      @version = handshake.version
      @frames = ::WebSocket::Frame::Incoming::Server.new(version: @version)
      @lines = +""
    end

    def gets
      until (idx = @lines.index("\n"))
        @frames << @io.readpartial(4096)
        while (frame = @frames.next)
          @lines << frame.data
        end
      end
      @lines.slice!(0, idx + 1)
    rescue EOFError
      nil
    end

    def write(data)
      @io.write(::WebSocket::Frame::Outgoing::Server.new(version: @version, data: data, type: :binary).to_s)
    end

    def close
      @io.close
    end
  end
end
