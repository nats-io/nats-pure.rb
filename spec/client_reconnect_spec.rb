# frozen_string_literal: true

describe "Client - Reconnect" do
  before do
    @s = NatsServerControl.new
    @s.start_server(true)
  end

  after do
    @s.kill_server
  end

  it "should process errors from a server and reconnect" do
    nats = NATS::IO::Client.new
    nats.connect({
      reconnect: true,
      reconnect_time_wait: 2,
      max_reconnect_attempts: 1
    })

    mon = Monitor.new
    done = mon.new_cond

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
      mon.synchronize { done.signal }
    end

    # Trigger invalid subject server error which the client
    # detects so that it will disconnect.
    nats.subscribe("hello.")

    # FIXME: This can fail due to timeout because
    # disconnection may have already occurred.
    begin
      nats.flush(1)
    rescue
      nil
    end

    # Should have a connection closed at this without reconnecting.
    mon.synchronize { done.wait(3) }
    expect(errors.count > 1).to eql(true)
    expect(errors.first).to be_a(NATS::IO::ServerError)
    expect(disconnects.count > 1).to eql(true)
    expect(disconnects.first).to be_a(NATS::IO::ServerError)
    expect(closes).to eql(0)

    nats.close
    expect(nats.closed?).to eql(true)
  end

  it "should reconnect to server and replay all subscriptions" do
    msgs = []
    errors = []
    closes = 0
    reconnects = 0
    disconnects = 0

    nats = NATS::IO::Client.new
    mon = Monitor.new
    done = mon.new_cond

    nats.on_error do |e|
      errors << e
    end

    nats.on_reconnect do
      reconnects += 1
    end

    nats.on_disconnect do
      disconnects += 1
    end

    nats.on_close do
      closes += 1
      mon.synchronize do
        done.signal
      end
    end

    nats.connect

    nats.subscribe("foo") do |msg|
      msgs << msg
    end

    nats.subscribe("bar") do |msg|
      msgs << msg
    end
    nats.flush

    nats.publish("foo", "hello.0")
    nats.flush
    @s.kill_server

    1.upto(10).each do |n|
      nats.publish("foo", "hello.#{n}")
      sleep 0.1
    end
    @s.start_server(true)
    sleep 1

    mon.synchronize { done.wait(1) }
    expect(disconnects).to eql(1)
    expect(msgs.count).to eql(11)
    expect(reconnects).to eql(1)
    expect(closes).to eql(0)

    # Cannot guarantee to get all of them since the server
    # was interrupted during send but at least some which
    # were pending during reconnect should have made it.
    expect(msgs.count > 5).to eql(true)
    expect(nats.status).to eql(NATS::IO::CONNECTED)

    nats.close
  end

  it "should abort reconnecting if disabled" do
    msgs = []
    errors = []
    closes = 0
    reconnects = 0
    disconnects = 0

    nats = NATS::IO::Client.new
    mon = Monitor.new
    done = mon.new_cond

    nats.on_error do |e|
      errors << e
    end

    nats.on_reconnect do
      reconnects += 1
    end

    nats.on_disconnect do
      disconnects += 1
    end

    nats.on_close do
      closes += 1
      mon.synchronize { done.signal }
    end

    nats.connect(reconnect: false)

    nats.subscribe("foo") do |msg|
      msgs << msg
    end

    nats.subscribe("bar") do |msg|
      msgs << msg
    end
    nats.flush

    nats.publish("foo", "hello")
    @s.kill_server

    10.times do
      nats.publish("foo", "hello")
      sleep 0.01
    end

    # Wait for a bit before checking state again
    mon.synchronize { done.wait(1) }
    expect(nats.last_error).to be_a(Errno::ECONNRESET)
    expect(nats.status).to eql(NATS::IO::DISCONNECTED)

    nats.close
  end

  it "should give up connecting if no servers available" do
    errors = []
    closes = 0
    reconnects = 0
    disconnects = []

    nats = NATS::IO::Client.new
    mon = Monitor.new
    done = mon.new_cond

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
      mon.synchronize { done.signal }
    end

    expect do
      nats.connect({
        servers: ["nats://127.0.0.1:4229"],
        max_reconnect_attempts: 2,
        reconnect_time_wait: 1
      })
    end.to raise_error(Errno::ECONNREFUSED)

    # Confirm that we have captured the sticky error
    # and that the connection has remained disconnected.
    expect(errors.first).to be_a(Errno::ECONNREFUSED)
    expect(errors.last).to be_a(Errno::ECONNREFUSED)
    expect(errors.count).to eql(3)
    expect(nats.last_error).to be_a(Errno::ECONNREFUSED)
    expect(nats.status).to eql(NATS::IO::DISCONNECTED)
  end

  it "should give up reconnecting if no servers available" do
    msgs = []
    errors = []
    closes = 0
    reconnects = 0
    disconnects = []

    nats = NATS::IO::Client.new
    mon = Monitor.new
    done = mon.new_cond

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
      mon.synchronize { done.signal }
    end

    nats.connect({
      servers: ["nats://127.0.0.1:4222"],
      max_reconnect_attempts: 1,
      reconnect_time_wait: 1
    })

    nats.subscribe("foo") do |msg|
      msgs << msg
    end

    nats.subscribe("bar") do |msg|
      msgs << msg
    end
    nats.flush

    nats.publish("foo", "hello.0")
    nats.flush
    @s.kill_server

    1.upto(10).each do |n|
      nats.publish("foo", "hello.#{n}")
      sleep 0.1
    end

    # Confirm that we have captured the sticky error
    # and that the connection is closed due no servers left.
    sleep 0.5
    mon.synchronize { done.wait(5) }
    expect(disconnects.count).to eql(2)
    expect(reconnects).to eql(0)
    expect(closes).to eql(1)
    expect(nats.last_error).to be_a(NATS::IO::NoServersError)
    expect(errors.first).to be_a(Errno::ECONNRESET)
    expect(errors.last).to be_a(Errno::ECONNREFUSED)
    expect(errors.count).to eql(3)
    expect(nats.status).to eql(NATS::IO::CLOSED)
  end

  context "against a server which is idle during connect" do
    before(:all) do
      # Start a fake tcp server
      @fake_nats_server = TCPServer.new 4444
      @fake_nats_server_th = Thread.new do
        loop do
          # Wait for a client to connect
          @fake_nats_server.accept
        rescue IOError
        end
      end
    end

    after(:all) do
      @fake_nats_server_th.exit
      @fake_nats_server.close
    end

    it "should give up reconnecting if no servers available due to timeout errors during connect" do
      errors = []
      closes = 0
      reconnects = 0
      disconnects = []

      nats = NATS::IO::Client.new
      mon = Monitor.new
      done = mon.new_cond

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
        mon.synchronize { done.signal }
      end

      nats.connect({
        servers: ["nats://127.0.0.1:4222", "nats://127.0.0.1:4444"],
        max_reconnect_attempts: 1,
        reconnect_time_wait: 1,
        dont_randomize_servers: true,
        connect_timeout: 1
      })

      # Trigger reconnect logic
      @s.kill_server
      mon.synchronize { done.wait(7) }

      expect(disconnects.count).to eql(2)
      expect(reconnects).to eql(0)
      expect(closes).to eql(1)
      expect(disconnects.last).to be_a(NATS::IO::NoServersError)
      expect(nats.last_error).to be_a(NATS::IO::NoServersError)
      expect(errors.first).to be_a(Errno::ECONNRESET)
      expect(errors[1]).to be_a(NATS::IO::SocketTimeoutError)
      expect(errors.last).to be_a(Errno::ECONNREFUSED)
      expect(errors.count).to eql(5)
      expect(nats.status).to eql(NATS::IO::CLOSED)
    end
  end

  context "against a server which becomes idle after being connected" do
    before(:all) do
      # Start a fake tcp server
      @fake_nats_server = TCPServer.new 4445
      @fake_nats_server_th = Thread.new do
        loop do
          # Wait for a client to connect
          client = @fake_nats_server.accept
          begin
            client.puts "INFO {}\r\n"

            # Read and ignore CONNECT command send by the client
            client.gets

            # Reply to any pending pings client may have sent
            sleep 0.1
            client.puts "PONG\r\n"

            # Make connection go stale so that client gives up
            sleep 10
          ensure
            client.close
          end
        end
      end
    end

    after(:all) do
      @fake_nats_server_th.exit
      @fake_nats_server.close
    end

    it "should reconnect to a healthy server if connection becomes stale" do
      errors = []
      closes = 0
      reconnects = 0
      disconnects = 0

      nats = NATS::IO::Client.new
      mon = Monitor.new
      done = mon.new_cond

      nats.on_error do |e|
        errors << e
      end

      nats.on_reconnect do
        reconnects += 1
      end

      nats.on_disconnect do
        disconnects += 1
      end

      nats.on_close do
        closes += 1
        mon.synchronize { done.signal }
      end

      nats.connect({
        servers: ["nats://127.0.0.1:4445", "nats://127.0.0.1:4222"],
        max_reconnect_attempts: -1,
        reconnect_time_wait: 2,
        dont_randomize_servers: true,
        connect_timeout: 1,
        ping_interval: 2
      })
      mon.synchronize { done.wait(7) }

      # Wrap up connection with server and confirm
      nats.close

      expect(disconnects).to eql(2)
      expect(reconnects).to eql(1)
      expect(closes).to eql(1)
      expect(errors.count).to eql(1)
      expect(errors.first).to be_a(NATS::IO::StaleConnectionError)
      expect(nats.last_error).to eql(nil)
      expect(nats.status).to eql(NATS::IO::CLOSED)
    end
  end

  context "against a server which stops following protocol after being connected" do
    before(:all) do
      # Start a fake tcp server
      @fake_nats_server = TCPServer.new 4446
      @fake_nats_server_th = Thread.new do
        loop do
          # Wait for a client to connect
          client = @fake_nats_server.accept
          begin
            client.puts "INFO {}\r\n"

            # Read and ignore CONNECT command send by the client
            client.gets

            # Reply to any pending pings client may have sent
            sleep 0.1
            client.puts "PONG\r\n"
            sleep 1

            client.puts "MSG MSG MSG MSG\r\n"
            sleep 10
          ensure
            client.close
          end
        end
      end
    end

    after(:all) do
      @fake_nats_server_th.exit
      @fake_nats_server.close
    end

    it "should reconnect to a healthy server after unknown protocol error" do
      errors = []
      closes = 0
      reconnects = 0
      disconnects = 0

      nats = NATS::IO::Client.new
      mon = Monitor.new
      done = mon.new_cond

      nats.on_error do |e|
        errors << e
      end

      nats.on_reconnect do
        reconnects += 1
      end

      nats.on_disconnect do
        disconnects += 1
        mon.synchronize { done.signal }
      end

      nats.on_close do
        closes += 1
      end

      nats.connect({
        servers: ["nats://127.0.0.1:4446", "nats://127.0.0.1:4222"],
        max_reconnect_attempts: -1,
        reconnect_time_wait: 2,
        dont_randomize_servers: true,
        connect_timeout: 1
      })
      # Wait for disconnect due to the unknown protocol error
      mon.synchronize { done.wait(7) }
      expect(errors.first).to be_a(NATS::IO::ServerError)
      expect(errors.first.to_s).to include("Unknown protocol")

      # Wait a bit for reconnect to occur
      sleep 1
      expect(nats.status).to eql(NATS::IO::CONNECTED)
      expect(disconnects).to eql(1)
      expect(reconnects).to eql(1)
      expect(closes).to eql(0)
      expect(errors.count).to eql(1)

      # Wrap up connection with server and confirm
      nats.close
      expect(nats.status).to eql(NATS::IO::CLOSED)
    end
  end

  context "against a server to which we have a stale connection after being connected" do
    before(:all) do
      # Start a fake tcp server
      @fake_nats_server = TCPServer.new 4447
      @fake_nats_server_th = Thread.new do
        loop do
          # Wait for a client to connect
          client = @fake_nats_server.accept
          begin
            client.puts "INFO {}\r\n"

            # Read and ignore CONNECT command send by the client
            client.gets

            # Reply to any pending pings client may have sent
            sleep 0.5
            client.puts "PONG\r\n"
            sleep 1

            client.puts "-ERR 'Stale Connection'\r\n"
            sleep 3
          ensure
            client.close
          end
        end
      end
    end

    after(:all) do
      @fake_nats_server_th.exit
      @fake_nats_server.close
    end

    it "should try to reconnect after receiving stale connection error" do
      errors = []
      closes = 0
      reconnects = 0
      disconnects = 0

      nats = NATS::IO::Client.new
      mon = Monitor.new
      done = mon.new_cond

      nats.on_error do |e|
        errors << e
      end

      nats.on_reconnect do
        reconnects += 1
      end

      nats.on_disconnect do
        disconnects += 1
        mon.synchronize { done.signal }
      end

      nats.on_close do
        closes += 1
      end

      nats.connect({
        servers: ["nats://127.0.0.1:4447"],
        max_reconnect_attempts: 1,
        reconnect_time_wait: 2,
        dont_randomize_servers: true,
        connect_timeout: 2
      })

      # Wait for disconnect due to the unknown protocol error
      mon.synchronize { done.wait(7) }
      expect(errors.first).to be_a(NATS::IO::StaleConnectionError)

      # Wait a bit for reconnect logic to trigger
      sleep 5
      expect(nats.status).to eql(NATS::IO::RECONNECTING)
      expect(disconnects).to eql(2)
      expect(reconnects).to eql(1)
      expect(closes).to eql(0)
      expect(errors.count).to eql(2)

      # Reconnect here
      sleep 5

      # Wrap up connection with server and confirm
      nats.close
      expect(nats.status).to eql(NATS::IO::CLOSED)
    end
  end
end
