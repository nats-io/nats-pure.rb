# frozen_string_literal: true

require "json"
require "openssl"
require "socket"

# A NATS server for the TLS and discovery specs. It listens on a free port
# of host, sends INFO, upgrades the connection to TLS when it has a
# context, answers PING with PONG and records the CONNECT of every client,
# with the server name the client sent in the handshake (SNI) as "sni". It
# also records what clients send in plaintext after a TLS handshake that
# failed.
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
  def initialize(tls: nil, later: nil, host: "127.0.0.1", info: {}, refuse: false)
    @tls = tls
    @later = later || tls
    @info = info
    @refuse = refuse
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

    io.write(info_line)
    if tls
      begin
        io = upgrade(sock, tls)
      rescue OpenSSL::SSL::SSLError
        return record_plaintext(sock)
      end
    end

    while (line = io.gets)
      case line
      when /\ACONNECT (.*)\r\n\z/
        connect = JSON.parse($1)
        @mutex.synchronize do
          @connects << connect.merge("sni" => @server_names.delete(io))
          @cond.broadcast
        end
        if @refuse
          io.write("-ERR 'Authorization Violation'\r\n")
          break
        end
      when "PING\r\n"
        io.write("PONG\r\n")
      end
    end
  rescue IOError, SystemCallError, OpenSSL::SSL::SSLError
    # The client went away.
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

  def info_line
    info = {server_id: "FAKE", version: "2.14.0", proto: 1, headers: true, max_payload: 1_048_576, tls_required: !@tls.nil?}
    "INFO #{info.merge(@info).to_json}\r\n"
  end

  def close_quietly(io)
    io.close
  rescue IOError, SystemCallError, OpenSSL::SSL::SSLError
    # Already closed.
  end
end
