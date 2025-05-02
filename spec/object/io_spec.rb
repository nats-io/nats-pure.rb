# frozen_string_literal: true

RSpec.describe NATS::Object::IO do
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

  subject { described_class.new(store, object.info, options) }

  let(:object) { store.put(name: "name", data: "data") }
  let(:options) { NATS::Object::Get::Options.new({}) }

  let!(:store) { context.stores.create(bucket: "bucket") }
  let(:context) { NATS.connect.object_store }

  after { store.delete }

  describe "#read" do
    after { subject.close }

    it "reads data from file" do
      expect(subject.read).to eq("data")
    end
  end

  describe "#eof?" do
    after { subject.close }

    context "when it is end of file" do
      before { subject.read }

      it "returns true" do
        expect(subject.eof?).to be(true)
      end
    end

    context "when it is not end of file" do
      it "returns false" do
        expect(subject.eof?).to be(false)
      end
    end
  end

  describe "#close" do
    it "closes file" do
      subject.close

      expect(subject.closed?).to be(true)
    end
  end

  describe "#closed?" do
    context "when file is closed" do
      before { subject.close }

      it "returns true" do
        expect(subject.closed?).to be(true)
      end
    end

    context "when file is not closed" do
      after { subject.close }

      it "returns false" do
        expect(subject.closed?).to be(false)
      end
    end
  end
end
