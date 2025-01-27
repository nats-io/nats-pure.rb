# frozen_string_literal: true

RSpec.describe NATS::Service::Monitoring do
  subject { described_class.new(service, prefix) }

  let(:prefix) { nil }

  let(:service) do
    instance_double(NATS::Service, name: "foo", id: "bar", client: client, status: status)
  end

  let(:status) do
    instance_double(NATS::Service::Status, basic: basic, info: info, stats: stats)
  end

  let(:basic) { {name: "foo", id: "bar", version: "1.0.0"} }
  let(:info) { {**basic, description: "foo bar"} }
  let(:stats) { {**basic, started: "2025-01-24T05:40:37Z"} }

  let(:client) { NATS.connect }
  let(:subs) { client.instance_variable_get("@subs") }

  before(:all) do
    @server = NatsServerControl.new
    @server.start_server(true)
  end

  after(:all) do
    @server.kill_server
  end

  after do
    subject.stop
    client.close
  end

  describe "#initialize" do
    context "when prefix is specified" do
      let(:prefix) { "$FOO" }

      it "starts monitoring with the specified prefix" do
        subject

        expect(subs.values).to include(
          having_attributes(subject: "$FOO.PING"),
          having_attributes(subject: "$FOO.PING.foo"),
          having_attributes(subject: "$FOO.PING.foo.bar"),
          having_attributes(subject: "$FOO.INFO"),
          having_attributes(subject: "$FOO.INFO.foo"),
          having_attributes(subject: "$FOO.INFO.foo.bar"),
          having_attributes(subject: "$FOO.STATS"),
          having_attributes(subject: "$FOO.STATS.foo"),
          having_attributes(subject: "$FOO.STATS.foo.bar")
        )
      end
    end

    context "when prefix is not specified" do
      let(:prefix) { nil }

      it "starts monitoring with the default prefix" do
        subject

        expect(subs.values).to include(
          having_attributes(subject: "$SRV.PING"),
          having_attributes(subject: "$SRV.PING.foo"),
          having_attributes(subject: "$SRV.PING.foo.bar"),
          having_attributes(subject: "$SRV.INFO"),
          having_attributes(subject: "$SRV.INFO.foo"),
          having_attributes(subject: "$SRV.INFO.foo.bar"),
          having_attributes(subject: "$SRV.STATS"),
          having_attributes(subject: "$SRV.STATS.foo"),
          having_attributes(subject: "$SRV.STATS.foo.bar")
        )
      end
    end

    describe "PING" do
      let(:ping_response) { {type: "io.nats.micro.v1.ping_response", **basic}.to_json }

      it "returns PING response" do
        subject

        expect(client.request("$SRV.PING")).to have_attributes(data: ping_response)
        expect(client.request("$SRV.PING.foo")).to have_attributes(data: ping_response)
        expect(client.request("$SRV.PING.foo.bar")).to have_attributes(data: ping_response)
      end
    end

    describe "INFO" do
      let(:info_response) { {type: "io.nats.micro.v1.info_response", **info}.to_json }

      it "returns INFO response" do
        subject

        expect(client.request("$SRV.INFO")).to have_attributes(data: info_response)
        expect(client.request("$SRV.INFO.foo")).to have_attributes(data: info_response)
        expect(client.request("$SRV.INFO.foo.bar")).to have_attributes(data: info_response)
      end
    end

    describe "STATS" do
      let(:stats_response) { {type: "io.nats.micro.v1.stats_response", **stats}.to_json }

      it "returns STATS response" do
        subject

        expect(client.request("$SRV.STATS")).to have_attributes(data: stats_response)
        expect(client.request("$SRV.STATS.foo")).to have_attributes(data: stats_response)
        expect(client.request("$SRV.STATS.foo.bar")).to have_attributes(data: stats_response)
      end
    end
  end

  describe "#stop" do
    context "when monitorings has not been started yet" do
      it "does nothing" do
        expect { subject.stop }.not_to raise_error
      end
    end

    context "when monitorings has been started" do
      it "drains monitoring subscriptions" do
        subject.stop

        expect(subs.values).to include(
          having_attributes(subject: "$SRV.PING", drained: true),
          having_attributes(subject: "$SRV.PING.foo", drained: true),
          having_attributes(subject: "$SRV.PING.foo.bar", drained: true),
          having_attributes(subject: "$SRV.INFO", drained: true),
          having_attributes(subject: "$SRV.INFO.foo", drained: true),
          having_attributes(subject: "$SRV.INFO.foo.bar", drained: true),
          having_attributes(subject: "$SRV.STATS", drained: true),
          having_attributes(subject: "$SRV.STATS.foo", drained: true),
          having_attributes(subject: "$SRV.STATS.foo.bar", drained: true)
        )
      end
    end
  end
end
