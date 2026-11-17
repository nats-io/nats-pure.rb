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
end
