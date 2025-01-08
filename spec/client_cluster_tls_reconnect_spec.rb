# frozen_string_literal: true

describe "Client - Cluster TLS reconnect" do
  before(:all) do
    s1_config_opts = {
      "pid_file" => "/tmp/nats_cluster_s1.pid",
      "host" => "127.0.0.1",
      "port" => 4232,
      "cluster_port" => 6232,
      "wsport" => 8232,
      "advertise" => "server-A.clients.nats-service.localhost:8232",
      "name" => "server-A"
    }

    s2_config_opts = {
      "pid_file" => "/tmp/nats_cluster_s2.pid",
      "host" => "127.0.0.1",
      "port" => 4233,
      "cluster_port" => 6233,
      "wsport" => 8233,
      "advertise" => "server-B.clients.nats-service.localhost:8233",
      "name" => "server-B"
    }

    s3_config_opts = {
      "pid_file" => "/tmp/nats_cluster_s3.pid",
      "host" => "127.0.0.1",
      "port" => 4234,
      "cluster_port" => 6234,
      "wsport" => 8234,
      "advertise" => "server-C.clients.nats-service.localhost:8234",
      "name" => "server-C"
    }

    nodes = []
    configs = [s1_config_opts, s2_config_opts, s3_config_opts]
    configs.each do |config_opts|
      nodes << NatsServerControl.init_with_config_from_string(%(
        host: '#{config_opts["host"]}'
        port:  #{config_opts["port"]}
        pid_file: '#{config_opts["pid_file"]}'
        server_name: '#{config_opts["name"]}'

        websocket {
          port: #{config_opts["wsport"]}
          tls {
            cert_file:  "./spec/configs/certs/nats-service.localhost/server.pem"
            key_file:   "./spec/configs/certs/nats-service.localhost/server-key.pem"
            ca_file:    "./spec/configs/certs/nats-service.localhost/ca.pem"
            timeout:   10
          }
          # NOTE: Force to reconnect using any other hostname other than the initial one.
          advertise: '#{config_opts["advertise"]}'
        }

        tls {
          cert_file:  "./spec/configs/certs/nats-service.localhost/server.pem"
          key_file:   "./spec/configs/certs/nats-service.localhost/server-key.pem"
          ca_file:   "./spec/configs/certs/nats-service.localhost/ca.pem"
          timeout:   10
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

  context "with auto discovery using seed node" do
    before do
      # Only start initial seed node
      @s1.start_server(true)
    end

    after do
      @s1.kill_server
    end

    it "should reconnect to nodes discovered from seed server" do
      # Nodes join to cluster before we try to connect
      [@s2, @s3].each do |s|
        s.start_server(true)
      end

      begin
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
        ctx = OpenSSL::SSL::SSLContext.new
        ctx.set_params
        ctx.ca_file = "./spec/configs/certs/nats-service.localhost/ca.pem"
        ctx.verify_mode = OpenSSL::SSL::VERIFY_PEER
        ctx.verify_hostname = true

        nats.connect("tls://server-A.clients.nats-service.localhost:4232", {
          dont_randomize_servers: true, reconnect: true, tls: {
            context: ctx
          }
        })
        expect(nats.connected_server.to_s).to eql("tls://server-A.clients.nats-service.localhost:4232")

        nats.subscribe("hello") { |msg, reply| nats.publish(reply, "") }
        nats.flush
        nats.request("hello", "world")

        @s1.kill_server
        sleep 0.1
        mon.synchronize do
          reconnected.wait(3)
        end

        # Reconnected...
        expect(nats.instance_variable_get("@hostname")).to eql("server-A.clients.nats-service.localhost")
        expect(nats.connected_server.to_s).to_not eql("")
        expect(["tls://127.0.0.1:4233", "tls://127.0.0.1:4234"].include?(nats.connected_server.to_s)).to eql(true)

        nats.request("hello", "world", timeout: 1)

        expect(reconnects).to eql(1)
        expect(disconnects).to eql(1)

        expect(errors.count >= 1).to eql(true)

        nats.close
      ensure
        # Wrap up test
        [@s2, @s3].each do |s|
          s.kill_server
        end
      end
    end

    it "should reconnect to nodes discovered from seed server with WebSockets" do
      skip "flaky"
      # Nodes join to cluster before we try to connect
      [@s2, @s3].each do |s|
        s.start_server(true)
      end

      begin
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
        ctx = OpenSSL::SSL::SSLContext.new
        ctx.set_params
        ctx.ca_file = "./spec/configs/certs/nats-service.localhost/ca.pem"
        ctx.verify_mode = OpenSSL::SSL::VERIFY_PEER
        ctx.verify_hostname = true

        nats.connect("wss://server-A.clients.nats-service.localhost:8232", {
          dont_randomize_servers: true, reconnect: true, tls: {
            context: ctx
          }
        })
        expect(nats.connected_server.to_s).to eql("wss://server-A.clients.nats-service.localhost:8232")

        nats.subscribe("hello") { |msg, reply| nats.publish(reply, "") }
        nats.flush
        nats.request("hello", "world")

        expect(nats.connected?).to eql(true)
        @s1.kill_server
        sleep 0.1
        mon.synchronize do
          reconnected.wait(3)
        end

        # Confirm that it has reconnected.
        expect(nats.connected?).to eql(true)

        # Reconnected...
        expect(nats.instance_variable_get("@hostname")).to eql("server-A.clients.nats-service.localhost")
        expect(nats.connected_server.to_s).to_not eql("")
        expect(["wss://server-B.clients.nats-service.localhost:8233", "wss://server-C.clients.nats-service.localhost:8234"].include?(nats.connected_server.to_s)).to eql(true)
        nats.request("hello", "world", timeout: 1)

        expect(reconnects).to eql(1)
        expect(disconnects).to eql(1)

        expect(errors.count >= 1).to eql(true)

        nats.close
      ensure
        # Wrap up test
        [@s2, @s3].each do |s|
          s.kill_server
        end
      end
    end
  end
end
