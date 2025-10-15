# frozen_string_literal: true

RSpec.describe NATS::Object::Put do
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

  describe "#put" do
    let(:put) { subject.put(name: "object", data: "string") }
    let(:object) { store.get("object", as: :string) }

    context "when object meta is invalid" do
      let(:put) { subject.put(data: "string") }

      it "raises meta error" do
        expect { put }.to raise_error(NATS::Utils::Config::EmptyError)
      end
    end

    context "when object does not exist" do
      it "replaces object info" do
        put

        expect(object.info).to have_attributes(
          name: "object",
          bucket: "bucket",
          description: nil,
          nuid: be_a(String),
          metadata: {},
          headers: {},
          options: have_attributes(link: nil, max_chunk_size: 131072),
          chunks: 1,
          size: 6,
          digest: be_a(String),
          deleted: false
        )
      end

      it "publishes object data" do
        put

        expect(object.data).to eq("string")
      end

      it "returns NATS::Object" do
        expect(put).to be_a(NATS::Object).and(
          have_attributes(
            info: have_attributes(name: "object"),
            data: be_a(StringIO).and(have_attributes(string: "string"))
          )
        )
      end
    end

    context "when object already exists" do
      let!(:old) { subject.put(name: "object", data: "data") }
      let(:old_chunks) { store.chunks.find(old.info.nuid) }

      it "replaces object info" do
        put

        expect(object.info).to have_attributes(
          name: "object",
          bucket: "bucket",
          description: nil,
          nuid: be_a(String),
          metadata: {},
          headers: {},
          options: have_attributes(link: nil, max_chunk_size: 131072),
          chunks: 1,
          size: 6,
          digest: be_a(String),
          deleted: false
        )
      end

      it "publishes object data" do
        put

        expect(object.data).to eq("string")
      end

      it "removes the old object data" do
        put

        expect(old_chunks).to be(nil)
      end

      it "returns NATS::Object" do
        expect(put).to be_a(NATS::Object).and(
          have_attributes(
            info: have_attributes(name: "object"),
            data: be_a(StringIO).and(have_attributes(string: "string"))
          )
        )
      end
    end
  end
end
