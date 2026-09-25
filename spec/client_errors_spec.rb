# frozen_string_literal: true

describe "Client - Errors" do
  before(:all) do
    @s = NatsServerControl.new
    @s.start_server(true)
  end

  after(:all) do
    @s.kill_server
  end

  it "should process errors from server" do
    nats = NATS::IO::Client.new
    nats.connect(reconnect: false)

    errors = []
    nats.on_error do |e|
      errors << e
    end

    disconnects = []
    nats.on_disconnect do |e|
      disconnects << e
    end

    closes = 0
    nats.on_close do
      closes += 1
    end

    # Trigger invalid subject server error which the client
    # detects so that it will disconnect
    nats.subscribe("hello.")

    # The server answers with -ERR, which the client reports as an
    # async error.
    wait_until(description: "the server error") { errors.any? }

    nats.close
    wait_until(description: "the client to close") { closes == 1 }
    expect(errors.count).to eql(1)
    expect(errors.first).to be_a(NATS::IO::ServerError)
    expect(disconnects.count).to eql(1)
    expect(disconnects.first).to be_a(NATS::IO::ServerError)
    expect(closes).to eql(1)
    expect(nats.closed?).to eql(true)
  end

  it "should handle unknown errors in the protocol" do
    nats = NATS::IO::Client.new
    nats.connect(reconnect: false)

    errors = []
    nats.on_error do |e|
      errors << e
    end

    disconnects = 0
    nats.on_disconnect do
      disconnects += 1
    end

    closes = 0
    nats.on_close do
      closes += 1
    end

    # Modify state from internal parser
    parser = nats.instance_variable_get("@parser")
    parser.parse("ASDF\r\n")
    wait_until(description: "the client to close") { closes == 1 }
    expect(errors.count).to eql(1)
    expect(errors.first).to be_a(NATS::IO::ServerError)
    expect(errors.first.to_s).to include("Unknown protocol")
    expect(disconnects).to eql(1)
    expect(closes).to eql(1)

    expect(nats.closed?).to eql(true)
  end

  it "should handle as async errors uncaught exceptions from callbacks" do
    nats = NATS::IO::Client.new
    nats.connect(reconnect: false)

    errors = []
    nats.on_error do |e|
      errors << e
    end

    disconnects = []
    nats.on_disconnect do |e|
      disconnects << e
    end

    closes = 0
    nats.on_close do
      closes += 1
    end

    # Trigger invalid subject server error which the client
    # detects so that it will disconnect
    custom_error = Class.new(StandardError)

    n = 0
    msgs = []
    nats.subscribe("hello") do |payload|
      n += 1

      if n == 2
        raise custom_error.new("NG!")
      end

      msgs << payload
    end

    5.times do
      nats.publish("hello")
    end
    begin
      nats.flush(1)
    rescue
      nil
    end

    eventually do
      expect(msgs.count).to eql(4)
      expect(errors.count).to eql(1)
    end

    nats.close
    wait_until(description: "the client to close") { closes == 1 }

    expect(msgs.count).to eql(4)
    expect(errors.count).to eql(1)
    expect(errors.first).to be_a(custom_error)
    expect(disconnects.count).to eql(1)
    expect(disconnects.first).to be_nil
    expect(closes).to eql(1)
    expect(nats.closed?).to eql(true)
  end

  it "should handle subscriptions with slow consumers as async errors when over pending msgs limit" do
    nats = NATS::IO::Client.new
    nats.connect(reconnect: false)

    errors = []
    nats.on_error do |nc, e, sub|
      errors << e
    end

    disconnects = []
    nats.on_disconnect do |e|
      disconnects << e
    end

    closes = 0
    nats.on_close do
      closes += 1
    end

    # Block the handler on the 5th message until the test has seen the
    # slow consumer error, so the pending queue overflows regardless of
    # machine speed.
    gate = Queue.new
    msgs = []
    sub = nats.subscribe("hello", pending_msgs_limit: 5) do |msg|
      msgs << msg.data
      gate.pop if msgs.count == 5
    end

    20.times do |n|
      nats.publish("hello", "ng-#{n}")
    end
    begin
      nats.flush(1)
    rescue
      nil
    end

    wait_until(description: "a slow consumer error") { errors.any? }
    gate << :go
    wait_until(description: "the subscriber to drain") { sub.pending_queue.empty? }

    3.times do |n|
      nats.publish("hello", "ok-#{n}")
    end
    begin
      nats.flush(1)
    rescue
      nil
    end
    wait_until(description: "the final messages") { 3.times.all? { |n| msgs.include?("ok-#{n}") } }

    nats.close
    wait_until(description: "the client to close") { closes == 1 }

    # Should have dropped some messages but include the last few
    3.times do |n|
      expect(msgs.include?("ok-#{n}")).to eql(true)
    end
    expect(errors.first).to be_a(NATS::IO::SlowConsumer)
    expect(disconnects.count).to eql(1)
    expect(disconnects.first).to be_a(NATS::IO::SlowConsumer)
    expect(closes).to eql(1)
    expect(nats.closed?).to eql(true)
  ensure
    # Never leave the handler thread blocked if the spec failed early.
    gate&.push(:go)
  end

  it "should handle subscriptions with slow consumers as async errors when over pending bytes limit" do
    nats = NATS::IO::Client.new
    nats.connect(reconnect: false)

    errors = []
    nats.on_error do |e|
      errors << e
    end

    disconnects = []
    nats.on_disconnect do |e|
      disconnects << e
    end

    closes = 0
    nats.on_close do
      closes += 1
    end

    gate = Queue.new
    data = ""
    sub = nats.subscribe("hello", pending_bytes_limit: 10) do |msg|
      data += msg.data
      gate.pop if data.size == 10
    end

    20.times do
      nats.publish("hello", "A")
    end
    begin
      nats.flush(1)
    rescue
      nil
    end
    wait_until(description: "a slow consumer error") { errors.any? }
    gate << :go
    wait_until(description: "the subscriber to drain") { sub.pending_queue.empty? }

    3.times do |n|
      nats.publish("hello", "B")
    end
    begin
      nats.flush(1)
    rescue
      nil
    end
    wait_until(description: "the final messages") { data.end_with?("BBB") }

    nats.close
    wait_until(description: "the client to close") { closes == 1 }

    # Should have dropped a few messages
    expect(errors.first).to be_a(NATS::IO::SlowConsumer)
    expect(disconnects.count).to eql(1)
    expect(disconnects.first).to be_a(NATS::IO::SlowConsumer)
    expect(closes).to eql(1)
    expect(nats.closed?).to eql(true)
  ensure
    # Never leave the handler thread blocked if the spec failed early.
    gate&.push(:go)
  end

  context "against a server which is idle" do
    before(:all) do
      # Start a fake tcp server
      @fake_nats_server = TCPServer.new 4555
      @fake_nats_server_th = Thread.new do
        loop do
          # Wait for a client to connect and linger
          @fake_nats_server.accept
        rescue IOError # ignore client disconnects
          break if @fake_nats_server.closed?
        end
      end
    end

    after(:all) do
      @fake_nats_server_th.exit
      @fake_nats_server.close
    end

    it "should fail due to timeout errors during connect" do
      errors = []
      closes = 0
      reconnects = 0
      disconnects = []

      nats = NATS::IO::Client.new

      nats.on_error do |e|
        errors << e
      end

      nats.on_reconnect do
        reconnects += 1
      end

      nats.on_disconnect do |e|
        disconnects << e
      end

      nats.on_close do
        closes += 1
      end

      expect do
        nats.connect({
          servers: ["nats://127.0.0.1:4555"],
          max_reconnect_attempts: 1,
          reconnect_time_wait: 0.1,
          connect_timeout: 0.2
        })
      end.to raise_error(NATS::IO::SocketTimeoutError)

      expect(disconnects.count).to eql(1)
      expect(reconnects).to eql(0)
      expect(closes).to eql(0)
      expect(disconnects.last).to be_a(NATS::IO::NoServersError)
      expect(nats.last_error).to be_a(NATS::IO::SocketTimeoutError)
      expect(errors.first).to be_a(NATS::IO::SocketTimeoutError)
      expect(errors.last).to be_a(NATS::IO::SocketTimeoutError)
      expect(errors.first).to be_a(NATS::Timeout)
      expect(errors.last).to be_a(NATS::Timeout)

      # Fails on the second reconnect attempt
      expect(errors.count).to eql(2)
      expect(nats.status).to eql(NATS::IO::DISCONNECTED)
    end
  end

  context "against a server with a custom INFO line" do
    before(:all) do
      # Start a fake tcp server
      @fake_nats_server = TCPServer.new 4556
      @fake_nats_server_th = Thread.new do
        loop do
          # Wait for a client to connect and linger
          client = @fake_nats_server.accept
          client.puts %(INFO {"version":"1.3.0 foo bar","max_payload": 1048576}\r\n)
          client.puts "PONG\r\n"
        rescue IOError # ignore client disconnects
          break if @fake_nats_server.closed?
        end
      end
    end

    after(:all) do
      @fake_nats_server_th.exit
      @fake_nats_server.close
    end

    it "should be able to connect" do
      errors = []

      nc = NATS::IO::Client.new
      closed = false

      nc.on_error do |e|
        errors << e
      end

      nc.on_close do
        closed = true
      end

      expect do
        nc.connect({
          servers: ["nats://127.0.0.1:4556"],
          reconnect: false,
          connect_timeout: 1
        })
      end.to_not raise_error

      nc.close
      wait_until(description: "the client to close") { closed }
      puts errors
    end
  end

  context "against a server with a custom malformed INFO line" do
    before(:all) do
      # Start a fake tcp server
      @fake_nats_server = TCPServer.new 4556
      @fake_nats_server_th = Thread.new do
        loop do
          # Wait for a client to connect and linger
          client = @fake_nats_server.accept
          begin
            client.puts %(INFO {foo)
          ensure
            client.close
          end
        rescue IOError # ignore client disconnects
          break if @fake_nats_server.closed?
        end
      end
    end

    after(:all) do
      @fake_nats_server_th.exit
      @fake_nats_server.close
    end

    it "should fail to connect" do
      errors = []

      nc = NATS::IO::Client.new
      closed = false

      nc.on_error do |e|
        errors << e
      end

      nc.on_close do
        closed = true
      end

      expect do
        nc.connect({
          servers: ["nats://127.0.0.1:4556"],
          reconnect: false,
          connect_timeout: 1
        })
      end.to raise_error(NATS::IO::ConnectError)

      nc.close
      wait_until(description: "the client to close") { closed }
      expect(errors.count).to eql(1)
      expect(errors.first).to be_a(NATS::IO::ConnectError)
    end
  end
end
