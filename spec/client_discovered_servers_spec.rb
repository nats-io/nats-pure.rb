# frozen_string_literal: true

require "timeout"

describe "Client - discovered servers" do
  let(:servers) { [] }

  after do
    servers.each(&:shutdown)
  end

  def fake_server(**opts)
    FakeNatsServer.new(**opts).tap { |s| servers << s }
  end

  def pool_urls(nats)
    nats.servers.map { |srv| srv[:uri].to_s }
  end

  # The certificates of these servers carry *.clients.nats-service.localhost,
  # and those of fakeserver *.clients.fake-nats-service.localhost.
  def tls_server(cert = "server", **opts)
    tls = FakeNatsServer.tls_context("nats-service.localhost/#{cert}.pem", "nats-service.localhost/#{cert}-key.pem")
    fake_server(tls: tls, **opts)
  end

  # These carry 127.0.0.1.
  def ip_tls_server(**opts)
    fake_server(tls: FakeNatsServer.tls_context("server.pem", "key.pem"), **opts)
  end

  def tls_options(ca = "nats-service.localhost/ca.pem", **opts)
    ctx = OpenSSL::SSL::SSLContext.new
    ctx.set_params(ca_file: "./spec/configs/certs/#{ca}")
    {context: ctx}.merge(opts)
  end

  context "with connect_urls entries" do
    # The seed lists entry and refuses the client, which then connects to
    # the server the entry names.
    def connect_through_seed(entry, url_userinfo: nil, **opts)
      other = fake_server(info: {nonce: "nonce"})
      seed = fake_server(refuse: true, info: {nonce: "nonce", connect_urls: [format(entry, other.port)]})
      userinfo = url_userinfo ? "#{url_userinfo}@" : ""
      nats = NATS::IO::Client.new
      nats.connect({servers: ["nats://#{userinfo}127.0.0.1:#{seed.port}"], reconnect_time_wait: 0.1}.merge(opts))
      connect = other.next_connect
      nats.close
      connect
    end

    it "logs in to a discovered server with the user's credentials, not the entry's user info" do
      connect = connect_through_seed("u:pw@127.0.0.1:%d", url_userinfo: "alice:secret")
      expect(connect).to include("user" => "alice", "pass" => "secret")
    end

    it "logs in to a discovered server with the user's credentials for an entry with only a user name" do
      connect = connect_through_seed("x@127.0.0.1:%d", url_userinfo: "alice:secret")
      expect(connect).to include("user" => "alice", "pass" => "secret")
      expect(connect).not_to include("auth_token")
    end

    it "keeps nkey authentication for an entry with user info" do
      connect = connect_through_seed("token@127.0.0.1:%d", nkeys_seed: "./spec/configs/nkeys/foo-user.nk")
      expect(connect).to include("nkey", "sig")
      expect(connect).not_to include("auth_token", "user")
    end

    it "skips an entry with a scheme" do
      canary = fake_server
      other = fake_server
      entries = ["nats", "tls", "ws", "WSS"].map { |scheme| "#{scheme}://127.0.0.1:#{canary.port}" }
      seed = fake_server(refuse: true, info: {connect_urls: entries + ["127.0.0.1:#{other.port}"]})
      nats = NATS::IO::Client.new

      nats.connect(servers: ["nats://127.0.0.1:#{seed.port}"], dont_randomize_servers: true, reconnect_time_wait: 0.1)
      expect(other.next_connect).not_to be_nil
      expect(pool_urls(nats)).to match_array(["nats://127.0.0.1:#{seed.port}", "nats://127.0.0.1:#{other.port}"])
      expect(canary.accepted).to eql(0)
      nats.close
    end

    it "skips an entry that is not host:port and uses the others" do
      other = fake_server
      entries = ["::::", "[::1", ":notaport", "a b:4222", "", "127.0.0.1", "127.0.0.1:0", "127.0.0.1:65536",
        "127.0.0.1:4998/path", "127.0.0.1:4997?x=1", "127.0.0.1:4996#x", 4222, nil]
      seed = fake_server(refuse: true, info: {connect_urls: entries + ["127.0.0.1:#{other.port}"]})
      nats = NATS::IO::Client.new

      nats.connect(servers: ["nats://127.0.0.1:#{seed.port}"], reconnect_time_wait: 0.1)
      expect(other.next_connect).not_to be_nil
      expect(pool_urls(nats)).to match_array(["nats://127.0.0.1:#{seed.port}", "nats://127.0.0.1:#{other.port}"])
      nats.close
    end

    it "takes an IPv6 entry in brackets, without its user info" do
      seed = fake_server(info: {connect_urls: ["[::1]:4999", "u:p@[::1]:4998"]})
      nats = NATS::IO::Client.new

      nats.connect(servers: ["nats://127.0.0.1:#{seed.port}"], reconnect: false)
      expect(pool_urls(nats)).to include("nats://[::1]:4999", "nats://[::1]:4998")
      nats.close
    end
  end

  context "with the first INFO of an attempt" do
    it "does not dial a server listed before a TLS handshake that fails" do
      name = "server-A.clients.nats-service.localhost"
      other = tls_server
      seed = tls_server("fakeserver", info: {connect_urls: ["#{name}:#{other.port}"]})
      nats = NATS::IO::Client.new

      expect do
        nats.connect(servers: ["tls://#{name}:#{seed.port}"], reconnect_time_wait: 0.1, max_reconnect_attempts: 1,
          tls: tls_options)
      end.to raise_error(OpenSSL::SSL::SSLError, /does not match the server certificate/)
      expect(other.accepted).to eql(0)
    end

    it "does not keep the servers of the INFO read before TLS" do
      seed = tls_server(info: {version: "2.11.0", connect_urls: ["127.0.0.1:4999"]})
      nats = NATS::IO::Client.new

      nats.connect(servers: ["tls://server-A.clients.nats-service.localhost:#{seed.port}"], reconnect: false,
        tls: tls_options)
      nats.flush
      expect(pool_urls(nats)).to eql(["tls://server-A.clients.nats-service.localhost:#{seed.port}"])
      nats.close
    end

    it "uses the servers of the first INFO of a refused plaintext attempt" do
      other = fake_server
      seed = fake_server(refuse: true, info: {connect_urls: ["127.0.0.1:#{other.port}"]})
      nats = NATS::IO::Client.new

      nats.connect(servers: ["nats://127.0.0.1:#{seed.port}"], reconnect_time_wait: 0.1)
      expect(other.next_connect).not_to be_nil
      nats.close
    end

    it "uses the servers of the first INFO of a refused attempt with handshake first" do
      other = ip_tls_server(tls_first: true)
      seed = ip_tls_server(tls_first: true, refuse: true, info: {connect_urls: ["127.0.0.1:#{other.port}"]})
      nats = NATS::IO::Client.new

      nats.connect(servers: ["tls://127.0.0.1:#{seed.port}"], reconnect_time_wait: 0.1,
        tls: tls_options("ca.pem", handshake_first: true))
      expect(other.next_connect).not_to be_nil
      nats.close
    end

    it "uses the servers of the first INFO of a refused attempt over wss" do
      other = ip_tls_server(websocket: true)
      seed = ip_tls_server(websocket: true, refuse: true, info: {connect_urls: ["127.0.0.1:#{other.port}"]})
      nats = NATS::IO::Client.new

      nats.connect(servers: ["wss://127.0.0.1:#{seed.port}"], reconnect_time_wait: 0.1, tls: tls_options("ca.pem"))
      expect(other.next_connect).not_to be_nil
      expect(nats.connected_server.to_s).to eql("wss://127.0.0.1:#{other.port}")
      nats.close
    end
  end

  context "with the INFO that follows the first PONG" do
    let(:listed) { "tls://127.0.0.1:4999" }

    def connect_tls(server, **opts)
      NATS::IO::Client.new.tap do |nats|
        nats.connect({servers: ["tls://127.0.0.1:#{server.port}"], reconnect: false, tls: tls_options("ca.pem")}.merge(opts))
      end
    end

    def elapsed
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      yield
      Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
    end

    it "knows the servers that INFO lists when connect returns" do
      server = ip_tls_server(first_ping: ["PONG\r\n", 0.3, {connect_urls: ["127.0.0.1:4999"]}])

      nats = connect_tls(server)
      expect(pool_urls(nats)).to include(listed)
      nats.close
    end

    it "waits for that INFO from a pre-release of 2.12" do
      server = ip_tls_server(info: {version: "2.12.0-RC.1"}, first_ping: ["PONG\r\n", 0.3, {connect_urls: ["127.0.0.1:4999"]}])

      nats = connect_tls(server)
      expect(pool_urls(nats)).to include(listed)
      nats.close
    end

    it "reports connected without that INFO after connect_timeout" do
      server = ip_tls_server(first_ping: ["PONG\r\n", 1.5, {connect_urls: ["127.0.0.1:4999"]}])

      nats = nil
      expect(elapsed { nats = connect_tls(server, connect_timeout: 0.5) }).to be_between(0.5, 1.4)
      expect(nats.connected?).to eql(true)
      expect(pool_urls(nats)).not_to include(listed)
      # The INFO that comes later is taken from the established connection.
      wait_until(description: "the servers of the later INFO") { pool_urls(nats).include?(listed) }
      nats.close
    end

    it "does not wait for a server before 2.12" do
      server = ip_tls_server(info: {version: "2.11.0"}, first_ping: ["PONG\r\n", 1.5, {connect_urls: ["127.0.0.1:4999"]}])

      nats = nil
      expect(elapsed { nats = connect_tls(server) }).to be < 1
      expect(nats.connected?).to eql(true)
      nats.close
    end

    it "does not wait with ignore_discovered_urls" do
      server = ip_tls_server(first_ping: ["PONG\r\n", 1.5, {connect_urls: ["127.0.0.1:4999"]}])

      nats = nil
      expect(elapsed { nats = connect_tls(server, ignore_discovered_urls: true) }).to be < 1
      expect(nats.connected?).to eql(true)
      nats.close
    end

    it "answers a PING while it waits" do
      server = ip_tls_server(first_ping: ["PONG\r\nPING\r\n", :await_pong, {connect_urls: ["127.0.0.1:4999"]}])

      nats = connect_tls(server)
      expect(pool_urls(nats)).to include(listed)
      nats.close
    end

    it "answers a PING and skips +OK before the first PONG" do
      server = fake_server(first_ping: ["+OK\r\nPING\r\n", :await_pong, "PONG\r\n"])
      nats = NATS::IO::Client.new

      nats.connect(servers: ["nats://127.0.0.1:#{server.port}"], reconnect: false)
      expect(nats.connected?).to eql(true)
      nats.close
    end

    it "fails the attempt after connect_timeout when the server sends PINGs and reads nothing" do
      # The client connects to one end of a socket pair, whose buffers are
      # small, so the client soon cannot write its PONGs.
      client_end, server_end = UNIXSocket.pair
      socket = NATS::IO::Socket.new
      allow(socket).to receive(:connect) { socket.socket = client_end }
      server = Thread.new do
        server_end.write("INFO #{{server_id: "PINGS", version: "2.14.0", proto: 1, max_payload: 1_048_576}.to_json}\r\n")
        seen = +""
        seen << server_end.readpartial(4096) until seen.include?("PING\r\n")
        loop { server_end.write("PING\r\n" * 1000) }
      rescue IOError, SystemCallError
        # The client went away.
      end
      nats = NATS::IO::Client.new
      # Only this client gets the socket pair, not a client of another
      # example that is still reconnecting.
      allow(nats).to receive(:create_socket).and_return(socket)

      took = elapsed do
        expect do
          # Timeout ends the example if the connect does not.
          Timeout.timeout(5) { nats.connect(servers: ["nats://127.0.0.1:4222"], reconnect: false, connect_timeout: 0.5) }
        end.to raise_error(NATS::IO::SocketTimeoutError)
      end
      expect(took).to be < 1.4
    ensure
      server&.kill
      [client_end, server_end].compact.each { |s| s.close unless s.closed? }
    end

    it "fails the attempt on -ERR while it waits" do
      server = ip_tls_server(first_ping: ["PONG\r\n-ERR 'Authorization Violation'\r\n"])

      expect { connect_tls(server) }.to raise_error(NATS::IO::ServerError, /Authorization Violation/)
    end

    it "fails the attempt on a line that does not parse while it waits" do
      server = ip_tls_server(first_ping: ["PONG\r\nNOT A PROTOCOL LINE\r\n"])

      expect { connect_tls(server) }.to raise_error(NATS::IO::ConnectError, /expected INFO, got NOT A PROTOCOL LINE/)
    end

    it "fails the attempt when the connection closes while it waits" do
      server = ip_tls_server(first_ping: ["PONG\r\n", :close])

      expect { connect_tls(server) }.to raise_error(NATS::IO::ConnectError, /expected INFO/)
    end

    it "replaces the discovered servers with the INFO that follows the first PONG on a reconnect" do
      other = ip_tls_server(info: {connect_urls: ["127.0.0.1:4997"]})
      seed = ip_tls_server(info: {connect_urls: ["127.0.0.1:#{other.port}", "127.0.0.1:4999"]})
      nats = NATS::IO::Client.new
      nats.connect(servers: ["tls://127.0.0.1:#{seed.port}"], dont_randomize_servers: true, reconnect_time_wait: 0.1,
        tls: tls_options("ca.pem"))
      expect(pool_urls(nats)).to include(listed)

      # The client goes on to the other server once the seed is gone.
      seed.shutdown
      wait_until(description: "a connection to the other server") do
        nats.connected_server.to_s == "tls://127.0.0.1:#{other.port}"
      end
      expect(pool_urls(nats)).not_to include(listed)
      expect(pool_urls(nats)).to include("tls://127.0.0.1:4997")
      nats.close
    end
  end

  context "with an INFO on the established connection" do
    def url(server_or_port)
      port = server_or_port.is_a?(Integer) ? server_or_port : server_or_port.port
      "nats://127.0.0.1:#{port}"
    end

    it "drops a discovered server that a later INFO no longer lists" do
      seed = fake_server(info: {connect_urls: ["127.0.0.1:4998", "127.0.0.1:4999"]})
      nats = NATS::IO::Client.new
      nats.connect(servers: [url(seed)], reconnect: false)
      expect(pool_urls(nats)).to match_array([url(seed), url(4998), url(4999)])

      seed.send_info(connect_urls: ["127.0.0.1:4998"])
      wait_until(timeout: 3, description: "a pool without 127.0.0.1:4999") do
        pool_urls(nats).sort == [url(seed), url(4998)].sort
      end
      nats.close
    end

    it "keeps the configured servers and the current server" do
      other = fake_server
      configured = fake_server(refuse: true)
      seed = fake_server(info: {connect_urls: ["127.0.0.1:#{other.port}", "127.0.0.1:4999"]})
      nats = NATS::IO::Client.new
      nats.connect(servers: [url(seed), url(configured)], dont_randomize_servers: true, reconnect_time_wait: 0.1)

      # The client goes on to the discovered server once the seed is gone.
      seed.shutdown
      wait_until(description: "a connection to the discovered server") { nats.connected_server.to_s == url(other) }

      # The current server does not list itself here.
      other.send_info(connect_urls: ["127.0.0.1:4997"])
      wait_until(timeout: 3, description: "a pool without 127.0.0.1:4999") do
        pool_urls(nats).sort == [url(seed), url(configured), url(other), url(4997)].sort
      end
      nats.close
    end

    it "keeps the discovered servers on an INFO without connect_urls" do
      seed = fake_server(info: {connect_urls: ["127.0.0.1:4999"]})
      nats = NATS::IO::Client.new
      nats.connect(servers: [url(seed)], reconnect: false)

      seed.send_info
      seed.send_info(connect_urls: [])
      nats.flush
      expect(pool_urls(nats)).to match_array([url(seed), url(4999)])
      nats.close
    end

    it "keeps the discovered servers on the first INFO of an attempt that fails" do
      kept = fake_server
      listed = fake_server(refuse: true)
      refusing = fake_server(refuse: true, info: {connect_urls: ["127.0.0.1:#{listed.port}"]})
      seed = fake_server(info: {connect_urls: ["127.0.0.1:#{listed.port}", "127.0.0.1:#{kept.port}"]})
      nats = NATS::IO::Client.new
      nats.connect(servers: [url(seed), url(refusing)], dont_randomize_servers: true, reconnect_time_wait: 0.1)

      # After the seed, the client tries the refusing server, which lists
      # only one of the discovered servers, and then those.
      seed.shutdown
      expect(kept.next_connect).not_to be_nil
      nats.close
    end
  end

  context "with the TLS name of a discovered server" do
    let(:seed_name) { "server-A.clients.nats-service.localhost" }

    # The fake server sees no SNI with jruby-openssl before 0.19.0, which
    # does not call servername_cb.
    def sni(name)
      (defined?(JOpenSSL::VERSION) && Gem::Version.new(JOpenSSL::VERSION) < Gem::Version.new("0.19.0")) ? nil : name
    end

    def tls_url(name, server)
      "tls://#{name}:#{server.port}"
    end

    # Trusts the CAs of both kinds of certificates.
    def both_ca_options(**opts)
      store = OpenSSL::X509::Store.new
      store.add_file("./spec/configs/certs/ca.pem")
      store.add_file("./spec/configs/certs/nats-service.localhost/ca.pem")
      ctx = OpenSSL::SSL::SSLContext.new
      ctx.set_params(cert_store: store)
      {context: ctx}.merge(opts)
    end

    # The certificates of these servers carry *.clients.nats-service.localhost,
    # not 127.0.0.1. The client goes on to the discovered server once the
    # seed is gone.
    it "verifies a discovered IP against the name of the server that listed it, in the servers: form" do
      other = tls_server
      seed = tls_server(info: {connect_urls: ["127.0.0.1:#{other.port}"]})
      nats = NATS::IO::Client.new
      nats.connect(servers: [tls_url(seed_name, seed)], reconnect_time_wait: 0.1, tls: tls_options)

      seed.shutdown
      expect(other.next_connect).to include("sni" => sni(seed_name))
      nats.close
    end

    it "verifies a discovered IP against the name of the server that listed it, after two hops" do
      third = tls_server
      second = tls_server(info: {connect_urls: ["127.0.0.1:#{third.port}"]})
      seed = tls_server(info: {connect_urls: ["127.0.0.1:#{second.port}"]})
      nats = NATS::IO::Client.new
      nats.connect(servers: [tls_url(seed_name, seed)], reconnect_time_wait: 0.1, tls: tls_options)

      seed.shutdown
      expect(second.next_connect).to include("sni" => sni(seed_name))
      wait_until(description: "the server listed by the second server") do
        pool_urls(nats).include?("tls://127.0.0.1:#{third.port}")
      end
      second.shutdown
      expect(third.next_connect).to include("sni" => sni(seed_name))
      nats.close
    end

    # The certificate of the discovered server carries
    # *.clients.fake-nats-service.localhost, not the seed's name.
    it "verifies a discovered host name against itself in the String form" do
      name = "server-A.clients.fake-nats-service.localhost"
      other = tls_server("fakeserver")
      seed = tls_server(info: {connect_urls: ["#{name}:#{other.port}"]})
      nats = NATS::IO::Client.new
      nats.connect(tls_url(seed_name, seed), reconnect_time_wait: 0.1, tls: tls_options)

      seed.shutdown
      expect(other.next_connect).to include("sni" => sni(name))
      nats.close
    end

    # The seed lists a host name and other, and the server with that name
    # lists other again. The certificate of other carries
    # *.clients.nats-service.localhost, not that host name.
    it "keeps the name of the server that listed a discovered IP first" do
      name = "server-A.clients.fake-nats-service.localhost"
      other = tls_server
      named = tls_server("fakeserver", info: {connect_urls: ["127.0.0.1:#{other.port}"]})
      seed = tls_server(info: {connect_urls: ["#{name}:#{named.port}", "127.0.0.1:#{other.port}"]})
      nats = NATS::IO::Client.new
      nats.connect(servers: [tls_url(seed_name, seed)], dont_randomize_servers: true, reconnect_time_wait: 0.1,
        tls: tls_options)

      seed.shutdown
      expect(named.next_connect).to include("sni" => sni(name))
      wait_until(description: "the connection to #{name}") { nats.connected_server&.port == named.port }
      nats.flush
      named.shutdown
      expect(other.next_connect).to include("sni" => sni(seed_name))
      nats.close
    end

    # The configured server refuses the client, so the pool drops it, and
    # the seed lists it. Its certificate carries 127.0.0.1, not the seed's
    # name.
    it "verifies a configured server against the host of its URL when a server lists it after the pool dropped it" do
      configured = ip_tls_server(refuse: true)
      seed = tls_server(info: {connect_urls: ["127.0.0.1:#{configured.port}"]})
      nats = NATS::IO::Client.new
      nats.connect(servers: [tls_url("127.0.0.1", configured), tls_url(seed_name, seed)], dont_randomize_servers: true,
        reconnect_time_wait: 0.1, max_reconnect_attempts: 0, tls: both_ca_options)
      expect(configured.next_connect).not_to be_nil

      seed.shutdown
      expect(configured.next_connect).not_to be_nil
      nats.close
    end

    # The INFO reaches the parser on a thread whose stop signal is
    # stopped, as in a read loop that close or a reconnect has stopped
    # and that has not ended yet.
    it "takes no servers from an INFO that a stopped read loop reads" do
      other = tls_server
      seed = tls_server
      nats = NATS::IO::Client.new
      nats.connect(servers: [tls_url(seed_name, seed)], reconnect: false, tls: tls_options)
      stop = NATS::IO::StopSignal.new
      stop.stop!
      Thread.new do
        Thread.current[:nats_stop] = stop
        nats.instance_variable_get("@parser").parse("INFO #{{connect_urls: ["127.0.0.1:#{other.port}"]}.to_json}\r\n")
      end.join

      expect(pool_urls(nats)).to eql([tls_url(seed_name, seed)])
      nats.close
    end
  end

  context "with a cluster of nats-servers with TLS" do
    before do
      @nodes = [[4580, 6580], [4581, 6581]].map do |port, cluster_port|
        NatsServerControl.init_with_config_from_string(%(
          host: "127.0.0.1"
          port: #{port}
          tls {
            cert_file: "./spec/configs/certs/server.pem"
            key_file: "./spec/configs/certs/key.pem"
            timeout: 10
          }
          cluster {
            name: "DISCOVERY"
            host: "127.0.0.1"
            port: #{cluster_port}
            routes = ["nats-route://127.0.0.1:6580", "nats-route://127.0.0.1:6581"]
          }
        ), {"pid_file" => "/tmp/test-nats-discovery.pid", "host" => "127.0.0.1", "port" => port})
      end
      @nodes.each(&:start_server)

      # A client that is connected learns the other node once the route is up.
      probe = NATS::IO::Client.new
      probe.connect(servers: ["tls://127.0.0.1:4580"], reconnect: false, tls: tls_options("ca.pem"))
      wait_until(description: "the route between the nodes") { pool_urls(probe).include?("tls://127.0.0.1:4581") }
      probe.close
    end

    after do
      @nodes.each(&:kill_server)
    end

    it "knows the cluster's servers when connect returns" do
      nats = NATS::IO::Client.new

      nats.connect(servers: ["tls://127.0.0.1:4580"], reconnect: false, tls: tls_options("ca.pem"))
      expect(pool_urls(nats)).to match_array(["tls://127.0.0.1:4580", "tls://127.0.0.1:4581"])
      nats.close
    end
  end
end
