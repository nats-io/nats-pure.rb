# frozen_string_literal: true

require "timeout"

describe NATS::IO::Socket do
  describe "#connect when the connection is refused" do
    subject(:socket) do
      described_class.new(uri: URI.parse("nats://127.0.0.1:65431"), connect_timeout: 1)
    end

    before do
      allow_any_instance_of(::Socket)
        .to receive(:connect_nonblock)
        .and_raise(IOError, "Connection refused")
    end

    if RUBY_ENGINE == "jruby"
      it "normalizes JRuby's plain IOError to Errno::ECONNREFUSED" do
        expect { socket.connect }.to raise_error(Errno::ECONNREFUSED)
      end
    else
      it "does not reclassify an IOError that mentions a refused connection" do
        expect { socket.connect }.to raise_error(IOError) do |error|
          expect(error).not_to be_a(SystemCallError)
        end
      end
    end
  end

  describe "#read_line over TLS" do
    let(:server) { FakeNatsServer.new(tls: FakeNatsServer.tls_context("server.pem", "key.pem")) }
    let(:threads) { [] }

    after do
      threads.each(&:kill)
      server.shutdown
    end

    # A socket to port that has read the INFO and completed the TLS
    # handshake.
    def tls_socket(port)
      ctx = OpenSSL::SSL::SSLContext.new
      ctx.set_params(ca_file: "./spec/configs/certs/ca.pem")
      socket = described_class.new(uri: URI.parse("nats://127.0.0.1:#{port}"), connect_timeout: 1,
        tls: {context: ctx, hostname: "127.0.0.1"})
      socket.connect
      expect(socket.read_line(1)).to start_with("INFO ")
      socket.setup_tls!
      socket
    end

    # Passes the bytes of one connection to a free port on to port and
    # back, and returns the free port. Once @slow is set, what comes from
    # port goes on in pieces of 16 bytes, 0.2 seconds apart.
    def relay(port)
      listener = TCPServer.new("127.0.0.1", 0)
      threads << Thread.new do
        client = listener.accept
        upstream = TCPSocket.new("127.0.0.1", port)
        threads << Thread.new { pass_on(client, upstream) }
        pass_on(upstream, client, slow: true)
      ensure
        listener.close
      end
      listener.addr[1]
    end

    def pass_on(from, to, slow: false)
      loop do
        data = from.readpartial(4096)
        while slow && @slow && data.bytesize > 16
          to.write(data.slice!(0, 16))
          sleep 0.2
        end
        to.write(data)
      end
    rescue IOError, SystemCallError
      # A side closed the connection.
    end

    it "reads an INFO that arrives in one TLS record with the PONG" do
      socket = tls_socket(server.port)

      # The server writes PONG and the INFO that follows it at once.
      socket.write("CONNECT {}\r\nPING\r\n")
      expect(socket.read_line(1)).to eql("PONG\r\n")
      expect(socket.read_line(1)).to start_with("INFO ")
      socket.close
    end

    it "hands what read_line read beyond the line to read" do
      socket = tls_socket(server.port)

      socket.write("CONNECT {}\r\nPING\r\n")
      expect(socket.read_line(1)).to eql("PONG\r\n")
      expect(socket.read(NATS::IO::MAX_SOCKET_READ_BYTES, 1)).to start_with("INFO ")
      socket.close
    end

    it "gives up on a line after its timeout while a TLS record arrives in pieces" do
      socket = tls_socket(relay(server.port))
      @slow = true

      # The TLS record of the PONG and the INFO after it comes in pieces.
      socket.write("CONNECT {}\r\nPING\r\n")
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      expect { socket.read_line(0.5) }.to raise_error(NATS::IO::SocketTimeoutError)
      expect(Process.clock_gettime(Process::CLOCK_MONOTONIC) - started).to be < 1.4
      socket.close
    end
  end

  describe "#read_line with a timeout" do
    it "gives up on a line after its timeout while bytes come that end no line" do
      listener = TCPServer.new("127.0.0.1", 0)
      writer = Thread.new do
        conn = listener.accept
        12.times do
          conn.write("x")
          sleep 0.25
        end
        conn.close
      rescue IOError, SystemCallError
        # The client closed the connection.
      end
      socket = described_class.new(uri: URI.parse("nats://127.0.0.1:#{listener.addr[1]}"), connect_timeout: 1)
      socket.connect

      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      expect { socket.read_line(0.5) }.to raise_error(NATS::IO::SocketTimeoutError)
      expect(Process.clock_gettime(Process::CLOCK_MONOTONIC) - started).to be < 1.4
    ensure
      socket&.close
      writer&.kill
      listener&.close
    end

    it "gives up on a line after its timeout while every read gives bytes that end no line" do
      socket = described_class.new(uri: URI.parse("nats://127.0.0.1:4222"), connect_timeout: 1)
      io = double("socket")
      allow(io).to receive(:read_nonblock) do
        sleep 0.05
        +"x"
      end
      socket.socket = io

      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      expect { Timeout.timeout(3) { socket.read_line(0.3) } }.to raise_error(NATS::IO::SocketTimeoutError)
      expect(Process.clock_gettime(Process::CLOCK_MONOTONIC) - started).to be < 1
    end
  end
end
