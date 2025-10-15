# frozen_string_literal: true

RSpec.describe NATS::Object::Store::Status do
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

  subject { described_class.new(store) }

  let!(:store) { context.stores.create(config) }
  let(:context) { NATS.connect.object_store }

  let(:config) do
    {
      bucket: "store",
      description: "description",
      ttl: 0.5.to_nsec,
      storage: "file",
      num_replicas: 1,
      compression: "s2",
      metadata: {key: :value}
    }
  end

  after { store.delete }

  describe "#initialize" do
    it "sets attributes" do
      expect(subject).to have_attributes(
        bucket: "store",
        description: "description",
        metadata: include(key: "value"),
        ttl: 0.5.to_nsec,
        storage: "file",
        num_replicas: 1,
        sealed: false,
        size: 0,
        compressed: true,
        backing_store: "JetStream"
      )
    end
  end
end
