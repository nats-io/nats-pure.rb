# frozen_string_literal: true

RSpec.describe NATS::Object::Context do
  before(:all) do
    @server = NatsServerControl.new(
      "nats://127.0.0.1:4222",
      "/tmp/test-nats.pid",
      "-js"
    )
    @server.start_server(true)
  end

  after(:all) do
    @server.kill_server
  end

  subject { described_class.new(client, params) }

  let(:params) { {} }
  let(:client) { NATS.connect }

  describe "#initialize" do
    context "with params" do
      let(:params) { {prefix: "$PREFIX"} }

      it "initializes js with the specified params" do
        expect(subject.js.api.subject).to eq("$PREFIX")
      end
    end

    context "without params" do
      it "initializes js with default prefix" do
        expect(subject.js.api.subject).to eq("$JS.API")
      end
    end
  end

  describe "#stores" do
    it "returns Store::List" do
      expect(subject.stores).to be_a(NATS::Object::Store::List)
    end
  end
end
