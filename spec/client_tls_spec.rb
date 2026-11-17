# frozen_string_literal: true

describe "Client - TLS spec" do
  context "when server requires TLS and no auth needed" do
    before do
      opts = {
        "pid_file" => "/tmp/test-nats-4444.pid",
        "host" => "127.0.0.1",
        "port" => 4444
      }
      config = ERB.new(%(
        net:  "<%= opts['host'] %>"
        port: <%= opts['port'] %>

        tls {
          cert_file:  "./spec/configs/certs/server.pem"
          key_file:   "./spec/configs/certs/key.pem"
          timeout:    10

      }))
      @tls_no_auth = NatsServerControl.init_with_config_from_string(config.result(binding), opts)
      @tls_no_auth.start_server
    end

    after do
      @tls_no_auth.kill_server
    end

    it "should error if client does not set secure connection and server requires it" do
      errors = []
      closes = 0
      disconnects = 0
      reconnects = 0

      nats = NATS::IO::Client.new
      nats.on_close { closes += 1 }
      nats.on_reconnect { reconnects += 1 }
      nats.on_disconnect { disconnects += 1 }
      nats.on_error do |e|
        errors << e
      end

      expect do
        nats.connect(servers: ["nats://127.0.0.1:4444"], reconnect: false)
      end.to raise_error(NATS::IO::ConnectError)

      # Async handler also gets triggered since defined
      expect(errors.count).to eql(1)
      expect(errors.first).to be_a(NATS::IO::ConnectError)

      # No close since we were not even connected
      expect(closes).to eql(0)
      expect(reconnects).to eql(0)
      expect(disconnects).to eql(1)
    end

    it "should allow to connect client with secure connection if server requires it" do
      if defined?(JOpenSSL::VERSION) && Gem::Version.new(JOpenSSL::VERSION) < Gem::Version.new("0.19.0")
        skip "jruby-openssl before 0.19.0 corrupts the TLS stream when one thread reads from an SSLSocket while another writes to it"
      end

      errors = []
      closes = 0
      disconnects = 0
      reconnects = 0

      nats = NATS::IO::Client.new
      nats.on_close { closes += 1 }
      nats.on_reconnect { reconnects += 1 }
      nats.on_disconnect { disconnects += 1 }
      nats.on_error do |e|
        errors << e
      end

      expect do
        tls_context = OpenSSL::SSL::SSLContext.new
        # ca_file through set_params: set afterwards, it adds the CA to the
        # default store that every default context of the process shares.
        tls_context.set_params(ca_file: "./spec/configs/certs/ca.pem")
        nats.connect({
          servers: ["tls://127.0.0.1:4444"],
          reconnect: false,
          tls: {
            context: tls_context
          }
        })
      end.to_not raise_error

      # Confirm basic secure publishing works
      msgs = []
      nats.subscribe("hello.*") do |msg|
        msgs << msg
      end
      nats.flush

      # Send some messages...
      100.times { |n| nats.publish("hello.#{n}", "world") }
      nats.flush
      sleep 0.5

      # Gracefully disconnect
      nats.close

      # Should have published 100 messages without errors
      expect(msgs.count).to eql(100)
      expect(errors.count).to eql(0)
      expect(closes).to eql(1)
      expect(reconnects).to eql(0)
      expect(disconnects).to eql(1)
    end

    it "refuses a server it cannot verify, with a context that sets no verify mode" do
      errors = []
      nats = NATS::IO::Client.new
      nats.on_error { |e| errors << e }

      # The context the README showed: no CA and no verify mode.
      tls_context = OpenSSL::SSL::SSLContext.new
      expect do
        nats.connect(servers: ["tls://127.0.0.1:4444"], reconnect: false, tls: {context: tls_context})
      end.to raise_error(OpenSSL::SSL::SSLError, /certificate verify failed/)
      expect(errors.first).to be_a(OpenSSL::SSL::SSLError)
    end

    it "connects with insecure_skip_verify and no context to a server it cannot verify" do
      nats = NATS::IO::Client.new
      nats.connect(servers: ["tls://127.0.0.1:4444"], reconnect: false, tls: {insecure_skip_verify: true})
      nats.flush
      expect(nats.connected?).to eql(true)
      nats.close
    end

    it "names the name it expected, the certificate's names and tls: {hostname:}" do
      mismatch = 'hostname "nats.example.com" does not match the server certificate of 127.0.0.1:4444'
      names = ', which is issued for "127.0.0.1", "::1", "localhost", "server.localhost"'
      setting = "; tls: {hostname:} sets the name every server is verified against"

      # On CRuby this context checks the name during the handshake, after
      # which OpenSSL 1.1 keeps no certificate to take the names from.
      checks_names = OpenSSL::SSL::SSLContext.new
      checks_names.set_params(ca_file: "./spec/configs/certs/ca.pem")
      keeps_certificate = defined?(JRUBY_VERSION) || OpenSSL::OPENSSL_VERSION_NUMBER >= 0x30000000
      # This one leaves the name to the client.
      checks_no_names = OpenSSL::SSL::SSLContext.new
      checks_no_names.ca_file = "./spec/configs/certs/ca.pem"
      checks_no_names.verify_mode = OpenSSL::SSL::VERIFY_PEER
      contexts = [[checks_names, keeps_certificate], [checks_no_names, true]]
      unless defined?(JRUBY_VERSION)
        # On CRuby this one completes the handshake after the name check
        # failed.
        checks_names_only = OpenSSL::SSL::SSLContext.new
        checks_names_only.set_params(ca_file: "./spec/configs/certs/ca.pem", verify_mode: OpenSSL::SSL::VERIFY_NONE)
        contexts << [checks_names_only, true]
      end

      contexts.each do |tls_context, with_names|
        expect do
          NATS::IO::Client.new.connect(servers: ["tls://127.0.0.1:4444"], reconnect: false,
            tls: {context: tls_context, hostname: "nats.example.com"})
        end.to raise_error(OpenSSL::SSL::SSLError, with_names ? mismatch + names + setting : mismatch + setting)
      end
    end

    it "fails with a TLS error against a server that sends INFO first" do
      tls_context = OpenSSL::SSL::SSLContext.new
      tls_context.set_params(ca_file: "./spec/configs/certs/ca.pem")

      expect do
        NATS::IO::Client.new.connect(servers: ["tls://127.0.0.1:4444"], reconnect: false,
          tls: {context: tls_context, handshake_first: true})
      end.to raise_error(OpenSSL::SSL::SSLError)
    end

    it "should allow to client to try to connect securely using tls scheme" do
      nats = NATS::IO::Client.new

      # Discard error since only want to confirm that TLS is setup due to scheme option.
      begin
        nats.connect("tls://127.0.0.1:4444", reconnect: false)
      rescue
        nil
      end
      expect(nats.options[:tls]).to_not be_nil
    end

    it "should allow custom secure connection contexts" do
      errors = []
      closes = 0
      disconnects = 0
      reconnects = 0

      nats = NATS::IO::Client.new
      nats.on_close { closes += 1 }
      nats.on_reconnect { reconnects += 1 }
      nats.on_disconnect { disconnects += 1 }
      nats.on_error do |e|
        errors << e
      end

      expect do
        tls_context = OpenSSL::SSL::SSLContext.new
        tls_context.ssl_version = :TLSv1

        nats.connect({
          servers: ["tls://127.0.0.1:4444"],
          reconnect: false,
          tls: {
            context: tls_context
          }
        })
      end.to raise_error(OpenSSL::SSL::SSLError)
    end
  end

  context "when server requires TLS and certificates" do
    before do
      opts = {
        "pid_file" => "/tmp/test-nats-4555.pid",
        "host" => "127.0.0.1",
        "port" => 4555
      }
      config = ERB.new(%(
        net:  "<%= opts['host'] %>"
        port: <%= opts['port'] %>

        tls {
          cert_file:  "./spec/configs/certs/server.pem"
          key_file:   "./spec/configs/certs/key.pem"
          timeout:    10

          # Optional certificate authority for clients
          ca_file:   "./spec/configs/certs/ca.pem"

          # Require a client certificate
          verify:    true

      }))
      @tlsverify = NatsServerControl.init_with_config_from_string(config.result(binding), opts)
      @tlsverify.start_server
    end

    after do
      @tlsverify.kill_server
    end

    it "should allow custom secure connection contexts" do
      errors = []
      closes = 0
      disconnects = 0
      reconnects = 0

      nats = NATS::IO::Client.new
      nats.on_close { closes += 1 }
      nats.on_reconnect { reconnects += 1 }
      nats.on_disconnect { disconnects += 1 }
      nats.on_error do |e|
        errors << e
      end

      expect do
        tls_context = OpenSSL::SSL::SSLContext.new
        tls_context.cert = OpenSSL::X509::Certificate.new File.open("./spec/configs/certs/client-cert.pem")
        tls_context.key = OpenSSL::PKey::RSA.new File.open("./spec/configs/certs/client-key.pem")
        tls_context.ca_file = "./spec/configs/certs/ca.pem"
        tls_context.verify_mode = OpenSSL::SSL::VERIFY_PEER

        nats.connect({
          servers: ["tls://127.0.0.1:4555"],
          reconnect: false,
          tls: {
            context: tls_context
          }
        })

        nats.subscribe("hello") do |msg, reply|
          nats.publish(reply, "ok")
        end

        response = nats.request("hello", "world")
        expect(response.data).to eql("ok")
      end.to_not raise_error
    end
  end

  context "when one of two servers has a certificate of another CA" do
    before do
      @servers = [
        [4561, "nats-service.localhost/server.pem", "nats-service.localhost/server-key.pem"],
        [4562, "server.pem", "key.pem"]
      ].map do |port, cert, key|
        config = %(
          net: "127.0.0.1"
          port: #{port}

          tls {
            cert_file: "./spec/configs/certs/#{cert}"
            key_file: "./spec/configs/certs/#{key}"
            timeout: 10
          })
        opts = {"pid_file" => "/tmp/test-nats-#{port}.pid", "host" => "127.0.0.1", "port" => port}
        NatsServerControl.init_with_config_from_string(config, opts).tap(&:start_server)
      end
    end

    after do
      @servers.each(&:kill_server)
    end

    it "reconnects to a server it verified after another server failed the chain check" do
      ctx = OpenSSL::SSL::SSLContext.new
      ctx.set_params(ca_file: "./spec/configs/certs/nats-service.localhost/ca.pem")
      reconnects = 0
      nats = NATS::IO::Client.new
      nats.on_reconnect { reconnects += 1 }

      # The certificate of the second server is issued by another CA.
      nats.connect(
        servers: ["tls://server-A.clients.nats-service.localhost:4561", "tls://server-A.clients.nats-service.localhost:4562"],
        dont_randomize_servers: true,
        reconnect_time_wait: 0.1,
        max_reconnect_attempts: -1,
        tls: {context: ctx}
      )
      nats.flush
      nats.force_reconnect

      wait_until(description: "a reconnect to the first server") { reconnects > 0 }
      expect(nats.connected_server.to_s).to eql("tls://server-A.clients.nats-service.localhost:4561")
      nats.close
    end
  end

  context "when server requires TLS and client enables host verification" do
    let(:tls_context) {
      ctx = OpenSSL::SSL::SSLContext.new
      ctx.ca_file = "./spec/configs/certs/nats-service.localhost/ca.pem"
      ctx.verify_mode = OpenSSL::SSL::VERIFY_PEER
      ctx.verify_hostname = true

      ctx
    }

    before do
      @tls_verify_host_server_uri = URI.parse("nats://127.0.0.1:4556")
      opts = {
        "pid_file" => "/tmp/test-nats-#{@tls_verify_host_server_uri.port}.pid",
        "host" => "127.0.0.1",
        "port" => @tls_verify_host_server_uri.port
      }
      config = ERB.new(%(
        net:  "<%= opts['host'] %>"
        port: <%= opts['port'] %>

        tls: {
          cert_file:  "./spec/configs/certs/nats-service.localhost/server.pem"
          key_file:   "./spec/configs/certs/nats-service.localhost/server-key.pem"
          timeout:    10

          # Optional certificate authority for clients
          ca_file:   "./spec/configs/certs/nats-service.localhost/ca.pem"

          # Require a client certificate
          # verify:    true

      }))
      @tls_verify_host = NatsServerControl.init_with_config_from_string(config.result(binding), opts)
      @tls_verify_host.start_server
    end

    after do
      @tls_verify_host.kill_server
    end

    it "should be able to connect and verify server hostname" do
      expect do
        nats = NATS::IO::Client.new

        nats.connect({
          servers: ["tls://server-A.clients.nats-service.localhost:#{@tls_verify_host_server_uri.port}"],
          reconnect: false,
          tls: {
            context: tls_context
          }
        })

        nats.subscribe("hello") do |msg, reply|
          nats.publish(reply, "ok")
        end

        response = nats.request("hello", "world")
        expect(response.data).to eql("ok")
      end.to_not raise_error
    end

    it "should not be able to connect if using wrong server hostname" do
      expect do
        nats = NATS::IO::Client.new

        nats.connect({
          servers: ["tls://server-A.clients.fake-nats-service.localhost:#{@tls_verify_host_server_uri.port}"],
          reconnect: false,
          tls: {
            context: tls_context
          }
        })

        nats.subscribe("hello") do |msg, reply|
          nats.publish(reply, "ok")
        end

        response = nats.request("hello", "world")
        expect(response.data).to eql("ok")
      end.to raise_error(OpenSSL::SSL::SSLError)
    end
  end

  context "when bad server requires TLS" do
    before do
      @tls_verify_host_bad_server_uri = URI.parse("nats://127.0.0.1:4557")
      opts = {
        "pid_file" => "/tmp/test-nats-#{@tls_verify_host_bad_server_uri.port}.pid",
        "host" => "127.0.0.1",
        "port" => @tls_verify_host_bad_server_uri.port
      }
      config = ERB.new(%(
        net:  "<%= opts['host'] %>"
        port: <%= opts['port'] %>

        tls: {
          cert_file:  "./spec/configs/certs/nats-service.localhost/fakeserver.pem"
          key_file:   "./spec/configs/certs/nats-service.localhost/fakeserver-key.pem"
          timeout:    10

          # Optional certificate authority for clients
          ca_file:   "./spec/configs/certs/nats-service.localhost/ca.pem"

          # Require a client certificate
          # verify:    true

      }))
      @tls_verify_bad_host = NatsServerControl.init_with_config_from_string(config.result(binding), opts)
      @tls_verify_bad_host.start_server
    end

    after do
      @tls_verify_bad_host.kill_server
    end

    it "refuses a certificate for another name when the context checks no names" do
      ctx = OpenSSL::SSL::SSLContext.new
      ctx.ca_file = "./spec/configs/certs/nats-service.localhost/ca.pem"
      ctx.verify_mode = OpenSSL::SSL::VERIFY_PEER
      ctx.verify_hostname = false

      expect do
        NATS::IO::Client.new.connect({
          servers: ["tls://server-A.clients.nats-service.localhost:#{@tls_verify_host_bad_server_uri.port}"],
          reconnect: false,
          tls: {
            context: ctx
          }
        })
      end.to raise_error(OpenSSL::SSL::SSLError, /does not match the server certificate/)
    end

    it "leaves the checks to the context with insecure_skip_verify" do
      ctx = OpenSSL::SSL::SSLContext.new
      ctx.ca_file = "./spec/configs/certs/nats-service.localhost/ca.pem"
      ctx.verify_mode = OpenSSL::SSL::VERIFY_PEER
      ctx.verify_hostname = false

      expect do
        nats = NATS::IO::Client.new

        nats.connect({
          servers: ["tls://server-A.clients.nats-service.localhost:#{@tls_verify_host_bad_server_uri.port}"],
          reconnect: false,
          tls: {
            context: ctx,
            insecure_skip_verify: true
          }
        })

        nats.subscribe("hello") do |msg, reply|
          nats.publish(reply, "ok")
        end

        response = nats.request("hello", "world")
        expect(response.data).to eql("ok")
      end.to_not raise_error
    end

    it "should not be able to connect if client enabled hostname verification" do
      ctx = OpenSSL::SSL::SSLContext.new
      ctx.ca_file = "./spec/configs/certs/nats-service.localhost/ca.pem"
      ctx.verify_mode = OpenSSL::SSL::VERIFY_PEER
      ctx.verify_hostname = true

      expect do
        nats = NATS::IO::Client.new

        nats.connect({
          servers: ["tls://server-A.clients.nats-service.localhost:#{@tls_verify_host_bad_server_uri.port}"],
          reconnect: false,
          tls: {
            context: ctx
          }
        })

        nats.subscribe("hello") do |msg, reply|
          nats.publish(reply, "ok")
        end

        response = nats.request("hello", "world")
        expect(response.data).to eql("ok")
      end.to raise_error(OpenSSL::SSL::SSLError)
    end

    it "should not be able to connect if client enabled hostname verification using tls as the scheme" do
      ctx = OpenSSL::SSL::SSLContext.new
      ctx.ca_file = "./spec/configs/certs/nats-service.localhost/ca.pem"
      ctx.verify_mode = OpenSSL::SSL::VERIFY_PEER
      ctx.verify_hostname = true

      expect do
        nats = NATS::IO::Client.new

        nats.connect("tls://server-A.clients.nats-service.localhost:#{@tls_verify_host_bad_server_uri.port}", {
          reconnect: false,
          tls: {
            context: ctx
          }
        })
      end.to raise_error(OpenSSL::SSL::SSLError)
    end
  end

  context "when server expects the TLS handshake first" do
    before do
      opts = {
        "pid_file" => "/tmp/test-nats-4558.pid",
        "host" => "127.0.0.1",
        "port" => 4558
      }
      config = ERB.new(%(
        net:  "<%= opts['host'] %>"
        port: <%= opts['port'] %>

        tls {
          cert_file:  "./spec/configs/certs/server.pem"
          key_file:   "./spec/configs/certs/key.pem"
          timeout:    10
          handshake_first: true
      }))
      @tls_first = NatsServerControl.init_with_config_from_string(config.result(binding), opts)
      @tls_first.start_server
    end

    after do
      @tls_first.kill_server
    end

    it "connects to a server that expects the TLS handshake first" do
      tls_context = OpenSSL::SSL::SSLContext.new
      tls_context.set_params(ca_file: "./spec/configs/certs/ca.pem")
      nats = NATS::IO::Client.new

      nats.connect(servers: ["tls://127.0.0.1:4558"], reconnect: false, tls: {context: tls_context, handshake_first: true})
      nats.subscribe("hello") { |msg, reply| nats.publish(reply, "ok") }
      expect(nats.request("hello", "world").data).to eql("ok")
      nats.close
    end

    it "refuses a server it cannot verify with the TLS handshake first" do
      # No CA and no verify mode.
      tls_context = OpenSSL::SSL::SSLContext.new
      expect do
        NATS::IO::Client.new.connect(servers: ["tls://127.0.0.1:4558"], reconnect: false,
          tls: {context: tls_context, handshake_first: true})
      end.to raise_error(OpenSSL::SSL::SSLError, /certificate verify failed/)
    end
  end

  context "when servers record what the client sends" do
    let(:servers) { [] }

    after do
      servers.each(&:shutdown)
    end

    def fake_server(cert, **opts)
      tls = FakeNatsServer.tls_context("nats-service.localhost/#{cert}.pem", "nats-service.localhost/#{cert}-key.pem")
      FakeNatsServer.new(tls: tls, **opts).tap { |s| servers << s }
    end

    # Trusts the CA of the nats-service.localhost certificates, and checks
    # no name itself.
    def ca_context
      ctx = OpenSSL::SSL::SSLContext.new
      ctx.ca_file = "./spec/configs/certs/nats-service.localhost/ca.pem"
      ctx.verify_mode = OpenSSL::SSL::VERIFY_PEER
      ctx
    end

    it "sends nothing on a connection whose certificate check failed" do
      # The connections after the first present a certificate of another CA.
      server = fake_server("server", later: FakeNatsServer.tls_context("server.pem", "key.pem"))
      nats = NATS::IO::Client.new
      published = false
      nats.on_disconnect do
        unless published
          published = true
          # Kept until the client is connected again.
          nats.publish("updates", "kept while reconnecting")
        end
      end

      nats.connect(
        servers: ["tls://server-A.clients.nats-service.localhost:#{server.port}"],
        reconnect_time_wait: 0.1,
        max_reconnect_attempts: 1,
        tls: {context: ca_context}
      )
      expect(server.next_connect).to_not be_nil
      nats.force_reconnect

      wait_until(description: "the client to stop reconnecting") { nats.closed? }
      server.wait_for_all_closed
      expect(server.plaintext).to_not include("PUB")
    end

    it "closes a connection whose handshake failed while it keeps reconnecting" do
      # The connections after the first present a certificate of another CA.
      server = fake_server("server", later: FakeNatsServer.tls_context("server.pem", "key.pem"))
      nats = NATS::IO::Client.new
      nats.connect(
        servers: ["tls://server-A.clients.nats-service.localhost:#{server.port}"],
        reconnect_time_wait: 0.5,
        max_reconnect_attempts: -1,
        tls: {context: ca_context}
      )
      expect(server.next_connect).to_not be_nil
      nats.force_reconnect

      expect(server.wait_for_accepted(2)).to eql(true)
      expect(server.wait_for_all_closed(2)).to eql(true)
    ensure
      nats&.close
    end

    it "closes a connection whose certificate failed the name check while it keeps reconnecting" do
      # The connections after the first present a certificate of the same CA
      # for *.clients.fake-nats-service.localhost.
      later = FakeNatsServer.tls_context("nats-service.localhost/fakeserver.pem", "nats-service.localhost/fakeserver-key.pem")
      server = fake_server("server", later: later)
      nats = NATS::IO::Client.new
      nats.connect(
        servers: ["tls://server-A.clients.nats-service.localhost:#{server.port}"],
        reconnect_time_wait: 0.5,
        max_reconnect_attempts: -1,
        tls: {context: ca_context}
      )
      expect(server.next_connect).to_not be_nil
      nats.force_reconnect

      expect(server.wait_for_accepted(2)).to eql(true)
      expect(server.wait_for_all_closed(2)).to eql(true)
    ensure
      nats&.close
    end

    it "sends nothing on close while an attempt waits for the server" do
      # The connections after the first get nothing, not even INFO.
      server = fake_server("server", later: :silent)
      nats = NATS::IO::Client.new
      nats.connect(
        servers: ["tls://server-A.clients.nats-service.localhost:#{server.port}"],
        connect_timeout: 5,
        reconnect_time_wait: 0.1,
        tls: {context: ca_context}
      )
      expect(server.next_connect).to_not be_nil
      nats.force_reconnect
      # Kept until the client is connected again.
      nats.publish("updates", "kept while reconnecting")

      expect(server.wait_for_accepted(2)).to eql(true)
      nats.close
      server.wait_for_all_closed
      expect(server.plaintext).to_not include("PUB")
    end

    it "closes the client and sends nothing when drained while reconnecting" do
      # The connections after the first get nothing, not even INFO.
      server = fake_server("server", later: :silent)
      nats = NATS::IO::Client.new
      nats.connect(
        servers: ["tls://server-A.clients.nats-service.localhost:#{server.port}"],
        connect_timeout: 5,
        reconnect_time_wait: 0.1,
        tls: {context: ca_context}
      )
      expect(server.next_connect).to_not be_nil
      nats.force_reconnect
      # Kept until the client is connected again.
      nats.publish("updates", "kept while reconnecting")

      expect(server.wait_for_accepted(2)).to eql(true)
      nats.drain
      expect(nats.closed?).to eql(true)
      server.wait_for_all_closed
      expect(server.plaintext).to_not include("PUB")
    end

    it "closes the client when on_disconnect drains it while reconnecting" do
      # The connections after the first get nothing, not even INFO.
      server = fake_server("server", later: :silent)
      nats = NATS::IO::Client.new
      nats.on_disconnect { nats.drain }
      nats.connect(
        servers: ["tls://server-A.clients.nats-service.localhost:#{server.port}"],
        connect_timeout: 5,
        reconnect_time_wait: 0.1,
        tls: {context: ca_context}
      )
      expect(server.next_connect).to_not be_nil
      nats.force_reconnect

      wait_until(description: "the client to close") { nats.closed? }
    end

    it "sends nothing on a connection that has not started TLS when on_error drains the client" do
      # The connections after the first get nothing, not even INFO.
      server = fake_server("server", later: :silent)
      nats = NATS::IO::Client.new
      drained = false
      published = false
      nats.on_error do
        unless drained
          drained = true
          nats.drain
        end
      end
      nats.on_disconnect do
        unless published
          published = true
          # Kept until the client is connected again.
          nats.publish("updates", "kept while reconnecting")
        end
      end
      nats.connect(
        servers: ["tls://server-A.clients.nats-service.localhost:#{server.port}"],
        connect_timeout: 5,
        reconnect_time_wait: 0,
        max_reconnect_attempts: -1,
        tls: {context: ca_context}
      )
      nats.subscribe("work") {}
      nats.flush

      server.drop_clients
      wait_until(description: "the client to close") { nats.closed? }
      server.wait_for_all_closed
      expect(server.plaintext).to_not include("PUB")
    end

    it "sends nothing on a connection that has not started TLS when connect is called again after a close while reconnecting" do
      # The connections after the first get nothing, not even INFO.
      server = fake_server("server", later: :silent)
      opts = {
        servers: ["tls://server-A.clients.nats-service.localhost:#{server.port}"],
        connect_timeout: 1,
        reconnect_time_wait: 0.1,
        max_reconnect_attempts: 1,
        tls: {context: ca_context}
      }
      nats = NATS::IO::Client.new
      nats.connect(opts)
      expect(server.next_connect).to_not be_nil
      nats.force_reconnect
      # Kept until the client is connected again.
      nats.publish("updates", "kept while reconnecting")
      expect(server.wait_for_accepted(2)).to eql(true)
      nats.close

      expect { nats.connect(opts) }.to raise_error(NATS::IO::SocketTimeoutError)
      server.wait_for_all_closed
      expect(server.plaintext).to_not include("PUB")
    end

    it "verifies a server reached by an IPv6 address against the certificate's IP addresses" do
      # server.pem is issued for the IP addresses 127.0.0.1 and ::1.
      server = FakeNatsServer.new(tls: FakeNatsServer.tls_context("server.pem", "key.pem"), host: "::1")
      servers << server
      ctx = OpenSSL::SSL::SSLContext.new
      ctx.set_params(ca_file: "./spec/configs/certs/ca.pem")
      nats = NATS::IO::Client.new

      nats.connect(servers: ["tls://[::1]:#{server.port}"], reconnect: false, tls: {context: ctx})
      expect(server.next_connect).to_not be_nil
      nats.close
    end

    it "verifies the server it reconnects to" do
      errors = []
      seed = fake_server("server")
      # Issued by the same CA for *.clients.fake-nats-service.localhost.
      other = fake_server("fakeserver")
      nats = NATS::IO::Client.new
      nats.on_error { |e| errors << e }

      nats.connect(
        servers: ["tls://server-A.clients.nats-service.localhost:#{seed.port}", "tls://server-A.clients.nats-service.localhost:#{other.port}"],
        dont_randomize_servers: true,
        reconnect_time_wait: 0.1,
        tls: {context: ca_context}
      )
      expect(seed.next_connect).to_not be_nil

      nats.force_reconnect
      wait_until(description: "a failed name check of the server reconnected to") do
        errors.any? { |e| e.is_a?(OpenSSL::SSL::SSLError) && e.message.include?("does not match the server certificate") }
      end
      expect(other.next_connect(0.5)).to be_nil
      nats.close
    end

    it "reconnects to a server it verified after another server failed the name check" do
      # Served with TLS 1.2 so that the reconnect to it resumes the TLS session.
      seed_tls = FakeNatsServer.tls_context("nats-service.localhost/server.pem", "nats-service.localhost/server-key.pem")
      seed_tls.max_version = OpenSSL::SSL::TLS1_2_VERSION
      seed = FakeNatsServer.new(tls: seed_tls).tap { |s| servers << s }
      # Issued by the same CA for *.clients.fake-nats-service.localhost.
      other = fake_server("fakeserver")
      ctx = OpenSSL::SSL::SSLContext.new
      ctx.set_params(ca_file: "./spec/configs/certs/nats-service.localhost/ca.pem")
      nats = NATS::IO::Client.new

      nats.connect(
        servers: ["tls://server-A.clients.nats-service.localhost:#{seed.port}", "tls://server-A.clients.nats-service.localhost:#{other.port}"],
        dont_randomize_servers: true,
        reconnect_time_wait: 0.1,
        tls: {context: ctx}
      )
      expect(seed.next_connect).to_not be_nil

      nats.force_reconnect
      expect(other.wait_for_accepted(1)).to eql(true)
      expect(seed.next_connect).to_not be_nil
      nats.close
    end

    it "sends CONNECT to no server whose certificate does not verify, with a context that sets no verify mode" do
      # Issued by another CA, and served with TLS 1.2 so that the reconnect
      # to it resumes the TLS session.
      other_tls = FakeNatsServer.tls_context("server.pem", "key.pem")
      other_tls.max_version = OpenSSL::SSL::TLS1_2_VERSION
      other = FakeNatsServer.new(tls: other_tls).tap { |s| servers << s }
      good = fake_server("server")
      ctx = OpenSSL::SSL::SSLContext.new
      ctx.ca_file = "./spec/configs/certs/nats-service.localhost/ca.pem"
      nats = NATS::IO::Client.new

      # On JRuby connect raises: the client refuses a context without VERIFY_PEER.
      connected = begin
        nats.connect(
          servers: ["tls://127.0.0.1:#{other.port}", "tls://server-A.clients.nats-service.localhost:#{good.port}"],
          dont_randomize_servers: true, reconnect_time_wait: 0.1, max_reconnect_attempts: 5,
          tls: {context: ctx}
        )
        true
      rescue OpenSSL::SSL::SSLError, NATS::IO::NoServersError
        false
      end
      if connected
        expect(good.next_connect).to_not be_nil
        nats.force_reconnect
        expect(other.wait_for_accepted(2)).to eql(true)
      end
      expect(other.next_connect(1)).to be_nil
    ensure
      nats&.close
    end

    it "verifies every server against tls: {hostname:} and sends it as SNI" do
      name = "server-A.clients.fake-nats-service.localhost"
      first = fake_server("fakeserver")
      second = fake_server("fakeserver")
      ctx = OpenSSL::SSL::SSLContext.new
      ctx.set_params(ca_file: "./spec/configs/certs/nats-service.localhost/ca.pem")
      nats = NATS::IO::Client.new

      # The certificates name server-A.clients.fake-nats-service.localhost,
      # not 127.0.0.1.
      nats.connect(
        servers: ["tls://127.0.0.1:#{first.port}", "tls://127.0.0.1:#{second.port}"],
        dont_randomize_servers: true,
        reconnect_time_wait: 0.1,
        max_reconnect_attempts: 1,
        tls: {context: ctx, hostname: name}
      )
      nats.force_reconnect

      # The fake server sees no SNI with jruby-openssl before 0.19.0, which
      # does not call servername_cb.
      sni = (defined?(JOpenSSL::VERSION) && Gem::Version.new(JOpenSSL::VERSION) < Gem::Version.new("0.19.0")) ? nil : name
      expect(first.next_connect["sni"]).to eql(sni)
      expect(second.next_connect["sni"]).to eql(sni)
      nats.close
    end
  end
end
