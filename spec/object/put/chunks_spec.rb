# frozen_string_literal: true

RSpec.describe NATS::Object::Put::Chunks do
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

  let(:meta) do
    NATS::Object::Put::Meta.new(
      name: "object",
      bucket: "bucket",
      nuid: "nuid",
      data: data,
      options: {max_chunk_size: 5}
    )
  end

  let(:messages) do
    messages_count.times.map do |seq|
      store.stream.messages.find(seq: seq + 1)
    end
  end

  let(:messages_count) do
    info = store.stream.info(subjects_filter: chunk_subject)
    info.state.subjects&.[](chunk_subject.to_sym) || 0
  end

  let(:chunk_subject) { "$O.bucket.C.nuid" }

  describe "#publish" do
    let(:publish) { subject.publish(meta) }
    let(:data) { "abc" }

    context "when everything goes smoothly" do
      it "closes data io after publishing" do
        publish

        expect(meta.data.closed?).to be(true)
      end
    end

    context "when an error occurs" do
      before do
        allow(context.js).to receive(:publish).and_raise(StandardError)
      end

      it "closes data io after publishing" do
        begin
          publish
        rescue
        end

        expect(meta.data.closed?).to be(true)
      end
    end

    context "when data size is 0" do
      let(:data) { "" }

      it "does not publish any messages" do
        publish

        expect(messages_count).to be(0)
      end

      it "returns zero chunks info" do
        expect(publish).to be_a(NATS::Object::Put::ChunksInfo).and(
          have_attributes(size: 0, chunks: 0)
        )
      end
    end

    context "when data size is less than max_chunk_size" do
      let(:data) { "abc" }

      it "publishes 1 message" do
        publish

        expect(messages).to match([
          have_attributes(data: "abc")
        ])
      end

      it "returns chunks info" do
        expect(publish).to be_a(NATS::Object::Put::ChunksInfo).and(
          have_attributes(size: 3, chunks: 1)
        )
      end
    end

    context "when data can be evenly divided in chunks" do
      let(:data) { "abcdefghijklmno" }

      it "divide data into multiple messages" do
        publish

        expect(messages).to match([
          have_attributes(data: "abcde"),
          have_attributes(data: "fghij"),
          have_attributes(data: "klmno")
        ])
      end

      it "returns chunks info" do
        expect(publish).to be_a(NATS::Object::Put::ChunksInfo).and(
          have_attributes(size: 15, chunks: 3)
        )
      end
    end

    context "when data can not be evenly divided in chunks" do
      let(:data) { "abcdefghijklmnopq" }

      it "divide data into multiple messages" do
        publish

        expect(messages).to match([
          have_attributes(data: "abcde"),
          have_attributes(data: "fghij"),
          have_attributes(data: "klmno"),
          have_attributes(data: "pq")
        ])
      end

      it "returns chunks info" do
        expect(publish).to be_a(NATS::Object::Put::ChunksInfo).and(
          have_attributes(size: 17, chunks: 4)
        )
      end
    end
  end
end
