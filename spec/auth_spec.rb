# frozen_string_literal: true

describe "Client - Authorization" do
  let(:auth_server) { "nats://secret:password@127.0.0.1:9222" }
  let(:auth_server_pid) { "/tmp/nats_authorization.pid" }
  let(:auth_server_no_cred) { "nats://127.0.0.1:9222" }

  let(:another_auth_server) { "nats://secret:secret@127.0.0.1:9223" }
  let(:another_auth_server_pid) { "/tmp/nats_another_authorization.pid" }

  let(:token_auth_server) { "nats://secret@127.0.0.1:9222" }
  let(:wrong_token_auth_server) { "nats://other@127.0.0.1:9222" }

  after do
    @server_control.kill_server
    FileUtils.rm_f auth_server_pid
  end

  it "should connect to an authorized server with proper credentials" do
    @server_control = NatsServerControl.new(auth_server, auth_server_pid)
    @server_control.start_server
    nats = NATS::IO::Client.new
    expect do
      nats.connect(servers: [auth_server], reconnect: false)
      nats.flush
    end.to_not raise_error
    nats.close
  end

  it "should connect to an authorized server with token" do
    @server_control = NatsServerControl.new(token_auth_server, auth_server_pid)
    @server_control.start_server
    nats = NATS::IO::Client.new
    expect do
      nats.connect(servers: [token_auth_server], reconnect: false)
      nats.flush
    end.to_not raise_error
    nats.close

    expect do
      nc = NATS.connect(token_auth_server, reconnect: false)
      nc.flush
      nc.close
    end.to_not raise_error

    expect do
      nc = NATS.connect(auth_server_no_cred, reconnect: false)
      nc.flush
      nc.close
    end.to raise_error(NATS::IO::AuthError)

    expect do
      nc = NATS.connect(auth_server_no_cred, reconnect: false, auth_token: "secret")
      nc.flush
      nc.close
    end.to_not raise_error

    expect do
      nc = NATS.connect(wrong_token_auth_server, reconnect: false, auth_token: "secret")
      nc.flush
      nc.close
    end.to_not raise_error
  end

  it "should fail to connect to an authorized server without proper credentials" do
    @server_control = NatsServerControl.new(auth_server, auth_server_pid)
    @server_control.start_server
    nats = NATS::IO::Client.new
    errors = []
    disconnect_errors = []
    expect do
      nats.on_disconnect do |e|
        disconnect_errors << e
      end
      nats.on_error do |e|
        errors << e
      end
      nats.connect({
        servers: [auth_server_no_cred],
        reconnect: false
      })
    end.to raise_error(NATS::IO::AuthError)
    expect(errors.count).to eql(1)
    expect(errors.first).to be_a(NATS::IO::AuthError)
    expect(disconnect_errors.count).to eql(1)
    expect(disconnect_errors.first).to be_a(NATS::IO::AuthError)
  end
end
