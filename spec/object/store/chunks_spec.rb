# frozen_string_literal: true

RSpec.describe NATS::Object::Store::Chunks do
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
    let(:publish) { subject.publish("nuid", "data") }

    let(:message) do
      # Find the message by iterating through stream messages
      stream_info = store.stream.info
      last_seq = stream_info.state.last_seq

      last_seq.downto([last_seq - 10, 1].max).each do |seq|
        msg = store.stream.messages.find(seq: seq)
        if msg.subject == "$O.bucket.C.nuid"
          break msg
        end
      rescue NATS::JetStream::MessageNotFoundError, NATS::JetStream::BadRequestError
        next
      end
    end

    it "publishes chunks" do
      publish

      expect(message.data).to eq("data")
    end

    it "returns data" do
      expect(publish).to eq("data")
    end
  end

  describe "#find" do
    let(:find) { subject.find("nuid") }

    context "when chunks exist" do
      before do
        subject.publish("nuid", "first")
        subject.publish("nuid", "last")
      end

      it "returns last chunk message" do
        expect(find).to be_a(NATS::Object::Chunk)
        expect(find.data).to eq("last")
      end
    end

    context "when no chunks exist" do
      it "returns nil" do
        expect(find).to be(nil)
      end
    end
  end

  describe "#purge" do
    let(:purge) { subject.purge("nuid") }

    before do
      subject.publish("nuid", "first")
      subject.publish("nuid", "last")
    end

    it "deletes chunk messages" do
      purge

      expect(subject.find("nuid")).to be(nil)
    end
  end

  describe "#consume" do
    let(:consume) do
      chunks = []

      consume = subject.consume("nuid") do |chunk, pull|
        chunks << chunk
        pull.stop if chunk.last?
      end

      consume.wait(1)
      chunks
    end

    before do
      subject.publish("nuid", "first")
      subject.publish("nuid", "last")
    end

    it "consumes chunk messages" do
      consume

      expect(consume).to match([
        be_a(NATS::Object::Chunk).and(have_attributes(data: "first")),
        be_a(NATS::Object::Chunk).and(have_attributes(data: "last"))
      ])
    end
  end
end
