# frozen_string_literal: true

describe "Client - Cluster reconnect" do
  before(:all) do
    auth_options = {
      "user" => "secret",
      "password" => "password",
      "token" => "asdf",
      "timeout" => 5
    }

    s1_config_opts = {
      "pid_file" => "/tmp/nats_cluster_s1.pid",
      "authorization" => auth_options,
      "host" => "127.0.0.1",
      "port" => 4242,
      "cluster_port" => 6222
    }

    s2_config_opts = {
      "pid_file" => "/tmp/nats_cluster_s2.pid",
      "authorization" => auth_options,
      "host" => "127.0.0.1",
      "port" => 4243,
      "cluster_port" => 6223
    }

    s3_config_opts = {
      "pid_file" => "/tmp/nats_cluster_s3.pid",
      "authorization" => auth_options,
      "host" => "127.0.0.1",
      "port" => 4244,
      "cluster_port" => 6224
    }

    nodes = []
    configs = [s1_config_opts, s2_config_opts, s3_config_opts]
    configs.each do |config_opts|
      nodes << NatsServerControl.init_with_config_from_string(%(
        host: '#{config_opts["host"]}'
        port:  #{config_opts["port"]}
        pid_file: '#{config_opts["pid_file"]}'
        authorization {
          user: '#{auth_options["user"]}'
          password: '#{auth_options["password"]}'
          timeout: #{auth_options["timeout"]}
        }
        cluster {
          name: "TEST"
          host: '#{config_opts["host"]}'
          port: #{config_opts["cluster_port"]}

          authorization {
            user: foo
            password: bar
            timeout: 5
          }

          routes = [
            'nats-route://foo:bar@127.0.0.1:#{s1_config_opts["cluster_port"]}'
          ]
        }
      ), config_opts)
    end

    @s1, @s2, @s3 = nodes
  end

  context "with cluster fully assembled when client connects" do
    before do
      [@s1, @s2, @s3].each do |s|
        s.start_server(true)
      end
    end

    after do
      [@s1, @s2, @s3].each do |s|
        s.kill_server
      end
    end

    it "should connect to another server if possible before reconnect" do
      @s3.kill_server

      reconnected = Future.new

      nats = NATS.connect(servers: [@s1.uri, @s2.uri], dont_randomize_servers: true)

      disconnects = 0
      nats.on_disconnect do
        disconnects += 1
      end

      closes = 0
      nats.on_close do
        closes += 1
      end

      reconnects = 0
      nats.on_reconnect do
        reconnects += 1
        reconnected.set_result(:ok)
      end

      msgs = []
      nats.subscribe("hello") do |msg|
        msgs << msg
      end
      nats.flush
      expect(nats.connected_server).to eql(@s1.uri)

      10.times do |n|
        nats.flush if n == 4
        @s1.kill_server if n == 5
        nats.publish("hello", "world.#{n}")
        sleep 0.1
      end

      expect(reconnected.wait_for(1)).to eq :ok
      expect(nats.connected_server).to eql(@s2.uri)
      nats.close

      expect(reconnects).to eql(1)
      expect(disconnects).to eql(2)
      expect(closes).to eql(1)
    end

    it "should connect to another server if possible before reconnect using multiple uris" do
      @s3.kill_server

      reconnected = Future.new

      nats = NATS::IO::Client.new
      nats.connect("nats://secret:password@127.0.0.1:4242,nats://secret:password@127.0.0.1:4243", dont_randomize_servers: true)

      disconnects = 0
      nats.on_disconnect do
        disconnects += 1
      end

      closes = 0
      nats.on_close do
        closes += 1
      end

      reconnects = 0
      nats.on_reconnect do
        reconnects += 1
        reconnected.set_result(:ok)
      end

      msgs = []
      nats.subscribe("hello") do |msg|
        msgs << msg
      end
      nats.flush
      expect(nats.connected_server.to_s).to eql(@s1.uri.to_s)

      10.times do |n|
        nats.flush if n == 4
        @s1.kill_server if n == 5
        nats.publish("hello", "world.#{n}")
        sleep 0.1
      end

      expect(reconnected.wait_for(1)).to eq :ok
      expect(nats.connected_server.to_s).to eql(@s2.uri.to_s)
      nats.close

      expect(reconnects).to eql(1)
      expect(disconnects).to eql(2)
      expect(closes).to eql(1)
    end

    it "should gracefully reconnect to another available server while publishing" do
      @s3.kill_server

      reconnected = Future.new

      nats = NATS::IO::Client.new
      nats.connect({
        servers: [@s1.uri, @s2.uri],
        dont_randomize_servers: true
      })

      disconnects = 0
      nats.on_disconnect do |e|
        disconnects += 1
      end

      closes = 0
      nats.on_close do
        closes += 1
      end

      reconnects = 0
      nats.on_reconnect do |s|
        reconnects += 1
        reconnected.set_result(:ok)
      end

      errors = []
      nats.on_error do |e|
        errors << e
      end

      msg_counter = 0
      nats.subscribe("hello.*") do |msg|
        msg_counter += 1
        if msg_counter == 100
          @s1.kill_server
        end
      end
      nats.flush
      expect(nats.connected_server.to_s).to eql(@s1.uri.to_s)

      msg_payload = "A" * 1_000
      100.times do |n|
        nats.publish("hello.#{n}", msg_payload)
      end

      # Flush everything we have sent so far
      nats.flush(5)

      expect(reconnected.wait_for(2)).to eq :ok
      expect(nats.connected_server).to eql(@s2.uri)
      nats.close

      expect(reconnects).to eql(1)
      expect(disconnects).to eql(2)
      expect(closes).to eql(1)
      expect(errors.size).to eq(1)
    end
  end

  context "with auto discovery using seed node" do
    before do
      # Only start initial seed node
      @s1.start_server(true)
    end

    after do
      [@s1, @s2, @s3].each do |s|
        s.kill_server
      end
    end

    context "with nodes joined before first connect" do
      before do
        [@s2, @s3].each do |s|
          s.start_server(true)
        end
      end

      it "should reconnect to nodes discovered from seed server" do
        reconnected = Future.new

        nats = NATS::IO::Client.new
        disconnects = 0
        nats.on_disconnect do
          disconnects += 1
        end

        closes = 0
        nats.on_close do
          closes += 1
        end

        reconnects = 0
        nats.on_reconnect do
          reconnects += 1
          reconnected.set_result(:ok)
        end

        errors = []
        nats.on_error do |e|
          errors << e
        end

        # Connect to first server only and trigger reconnect
        nats.connect(servers: [@s1.uri], dont_randomize_servers: true, reconnect: true)
        expect(nats.connected_server).to eql(@s1.uri)
        @s1.kill_server
        sleep 0.2

        reconnected.wait_for(3)

        # Reconnected...
        # expect(nats.connected_server).to eql(@s2.uri)
        expect(reconnects).to eql(1)
        expect(disconnects).to eql(1)
        expect(closes).to eql(0)
        expect(errors.count).to eql(1)
        expect(errors.first).to be_a(Errno::ECONNRESET)

        # There should be no error since we reconnected now
        expect(nats.last_error).to eql(nil)

        nats.close
      end

      it "should reconnect to nodes discovered from seed server with single uri" do
        skip "FIXME: flaky test"

        mon = Monitor.new
        reconnected = mon.new_cond

        nats = NATS::IO::Client.new
        disconnects = 0
        nats.on_disconnect do
          disconnects += 1
        end

        closes = 0
        nats.on_close do
          closes += 1
        end

        reconnects = 0
        nats.on_reconnect do
          reconnects += 1
          mon.synchronize do
            reconnected.signal
          end
        end

        errors = []
        nats.on_error do |e|
          errors << e
        end

        # Connect to first server only and trigger reconnect
        nats.connect("nats://secret:password@127.0.0.1:4242", dont_randomize_servers: true, reconnect: true, reconnect_time_wait: 0.5)
        expect(nats.connected_server.to_s).to eql(@s1.uri.to_s)
        @s1.kill_server
        sleep 0.1
        mon.synchronize do
          reconnected.wait(3)
        end

        # Reconnected...
        expect(nats.connected_server).to eql(@s2.uri)
        expect(reconnects).to eql(1)
        expect(disconnects).to eql(1)
        expect(closes).to eql(0)
        expect(errors.count).to eql(1)
        expect(errors.first).to be_a(Errno::ECONNRESET)

        # There should be no error since we reconnected now
        expect(nats.last_error).to eql(nil)

        nats.close
      end
    end

    it "should reconnect to nodes discovered in the cluster after first connect" do
      reconnected = Future.new

      nats = NATS::IO::Client.new
      disconnects = 0
      nats.on_disconnect do
        disconnects += 1
      end

      closes = 0
      nats.on_close do
        closes += 1
      end

      reconnects = 0
      nats.on_reconnect do
        reconnects += 1
        reconnected.set_result(:ok)
      end

      errors = []
      nats.on_error do |e|
        errors << e
      end

      # Connect to first server only and trigger reconnect
      nats.connect({
        servers: [@s1.uri],
        dont_randomize_servers: true,
        user: "secret",
        pass: "password",
        max_reconnect_attempts: 10
      })
      expect(nats.connected_server).to eql(@s1.uri)

      # Couple of servers join...
      [@s2, @s3].each do |s|
        s.start_server(true)
      end
      nats.flush

      # Wait for a bit before disconnecting from original server
      nats.flush
      @s1.kill_server

      reconnected.wait_for(3)

      # We still consider the original node and we have new ones
      # which can be used to failover.
      expect(nats.servers.count).to eql(3)

      # Only 2 new ones should be discovered servers even after reconnect
      expect(nats.discovered_servers.count).to eql(2)
      expect(nats.connected_server).to eql(@s2.uri)
      expect(reconnects).to eql(1)
      expect(disconnects).to eql(1)
      expect(closes).to eql(0)
      expect(errors.count).to eql(2)
      expect(errors.first).to be_a(Errno::ECONNRESET)
      expect(errors.last).to be_a(Errno::ECONNREFUSED)
      expect(nats.last_error).to be_a(Errno::ECONNREFUSED)

      nats.close
    end
  end
end
