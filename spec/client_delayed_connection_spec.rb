# frozen_string_literal: true

describe "Client - Delayed Connection" do
  let(:server) do
    NatsServerControl.new("nats://127.0.0.1:4522", "/tmp/test-nats.pid", "--cluster nats://127.0.0.1:4248 --cluster_name test-cluster")
  end

  context "when server isn't available" do
    it "should not raise error on client init" do
      expect do
        nc = NATS::Client.new(servers: [server.uri])
        nc.close
      end.to_not raise_error
    end

    it "should raise error on connect" do
      expect do
        nc = NATS::Client.new
        nc.connect(servers: [server.uri])
        nc.close
      end.to raise_error(Errno::ECONNREFUSED)
    end
  end

  context "when server is available" do
    before { server.start_server(true) }
    after { server.kill_server && sleep(0.1) }

    it "connects to the server on the first command and works" do
      nc = NATS::Client.new(servers: [server.uri])
      nc.connect
      nc.subscribe("service") do |msg|
        msg.respond("pong")
      end

      resp = nc.request("service", "ping")
      expect(resp.data).to eq("pong")

      nc.close
    end
  end
end
