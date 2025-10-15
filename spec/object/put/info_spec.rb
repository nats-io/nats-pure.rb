# frozen_string_literal: true

RSpec.describe NATS::Object::Put::Info do
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

  let!(:store) { context.stores.create(bucket: "bucket") }
  let(:context) { NATS.connect.object_store }

  after { store.delete }

  describe "#publish" do
    let(:publish) { subject.publish(meta, chunks) }

    let(:meta) do
      NATS::Object::Put::Meta.new(
        name: "object",
        bucket: "bucket",
        nuid: "nuid",
        data: "data",
        options: {max_chunk_size: 5}
      )
    end

    let(:chunks) do
      chunks = NATS::Object::Put::ChunksInfo.new
      chunks.published("data")

      chunks
    end

    it "publishes meta and chunks as info" do
      publish

      expect(store.meta.find("object")).to have_attributes(
        name: "object",
        bucket: "bucket",
        nuid: "nuid",
        options: have_attributes(max_chunk_size: 5),
        size: 4,
        chunks: 1,
        digest: be_a(String)
      )
    end
  end
end
