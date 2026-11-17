# frozen_string_literal: true

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
end
