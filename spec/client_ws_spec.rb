# frozen_string_literal: true

describe "Client - WebSocket spec" do
  before do
    @natsctl = NatsServerControl.init_with_config_from_string(config.result(binding), opts)
    @natsctl.start_server(true)
  end

  after do
    @natsctl.kill_server
  end

  context "when server accepts websocket connections without TLS" do
    let :opts do
      {
        "pid_file" => "/tmp/test-nats-8080.pid",
        "host" => "127.0.0.1",
        "port" => 4080,
        "wsport" => 8080
      }
    end
    let :config do
      ERB.new(<<~CONF)
        net:  "<%= opts['host'] %>"
        port: <%= opts['port'] %>
        websocket {
          port: <%= opts['wsport'] %>
          no_tls: true
        }
      CONF
    end

    it "should work" do
      nats = NATS.connect("ws://localhost:8080")

      nats.subscribe("hello") do |msg, reply|
        nats.publish(reply, "ok")
      end

      response = nats.request("hello", "world")
      expect(response.data).to eql("ok")
    end
  end

  context "when server requires TLS for websocket connections" do
    let :opts do
      {
        "pid_file" => "/tmp/test-nats-8443.pid",
        "host" => "127.0.0.1",
        "port" => 4443,
        "wsport" => 8443
      }
    end
    let :config do
      ERB.new(<<~CONF)
        net:  "<%= opts['host'] %>"
        port: <%= opts['port'] %>
        websocket {
          port: <%= opts['wsport'] %>
          tls {
            cert_file:  "./spec/configs/certs/server.pem"
            key_file:   "./spec/configs/certs/key.pem"
          }
        }
      CONF
    end

    it "refuses a wss:// server it cannot verify" do
      # No CA and no verify mode.
      tls_context = OpenSSL::SSL::SSLContext.new
      expect do
        NATS.connect(servers: ["wss://localhost:8443"], reconnect: false, tls: {context: tls_context})
      end.to raise_error(OpenSSL::SSL::SSLError, /certificate verify failed/)
    end

    # Flaky on JRuby due to NATS::IO::SocketTimeoutError
    it "should connect over TLS", skip: defined?(JRUBY_VERSION) do
      tls_context = OpenSSL::SSL::SSLContext.new
      # ca_file through set_params: set afterwards, it adds the CA to the
      # default store that every default context of the process shares.
      tls_context.set_params(ca_file: "./spec/configs/certs/ca.pem")
      nats = NATS.connect(
        servers: ["wss://localhost:8443"],
        reconnect: false,
        tls: {
          context: tls_context
        }
      )

      nats.subscribe("hello") do |msg, reply|
        nats.publish(reply, "ok")
      end

      response = nats.request("hello", "world")
      expect(response.data).to eql("ok")
    end
  end
end
