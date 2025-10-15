# frozen_string_literal: true

RSpec.describe NATS::Object::Get::Chunks do
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

  let(:info) do
    NATS::Object::Info.new(
      bucket: "bucket",
      nuid: "nuid",
      size: size,
      digest: "SHA-256=kYqVSsTftUrDnwaNmGgif2mrObw2LiybAIO_ahCdatc="
    )
  end

  let(:size) { 17 }

  describe "#get" do
    let(:get) { subject.get(info, options) }
    let(:options) { NATS::Object::Get::Options.new(timeout: 1) }

    let(:data) { File.read(get.io.path) }

    context "when there are no chunks messages" do
      let(:size) { 0 }

      it "returns nil" do
        expect(get).to be(nil)
      end
    end

    context "when there are chunks messages" do
      before do
        store.chunks.publish("nuid", "abcde")
        store.chunks.publish("nuid", "fghij")
        store.chunks.publish("nuid", "klmno")
        store.chunks.publish("nuid", "pq")
      end

      it "reads all the chunk messages" do
        get

        expect(data).to eq("abcdefghijklmnopq")
      end

      it "closes the data file" do
        get

        expect(get.io.closed?).to be(true)
      end
    end

    context "when an error occurs" do
      before do
        allow(subject).to receive(:write) do |data, chunk|
          data << chunk.data
          chunk.message.ack

          raise StandardError
        end

        store.chunks.publish("nuid", "abcde")
        store.chunks.publish("nuid", "fghij")
        store.chunks.publish("nuid", "klmno")
        store.chunks.publish("nuid", "pq")
      end

      it "raises DigestMismatchError" do
        expect { get }.to raise_error(NATS::Object::DigestMismatchError)
      end
    end
  end
end
