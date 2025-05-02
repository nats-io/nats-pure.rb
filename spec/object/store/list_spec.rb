# frozen_string_literal: true

RSpec.describe NATS::Object::Store::List do
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

  subject { described_class.new(context) }

  let(:context) { NATS.connect.object_store }
  let(:js) { context.js }

  after { js.streams.each(&:delete) }

  describe "#find" do
    let(:find) { subject.find("bucket") }

    context "when store exists" do
      let!(:store) { subject.create(bucket: "bucket") }

      it "returns store with the specified name" do
        expect(find).to be_a(NATS::Object::Store).and(
          have_attributes(
            config: have_attributes(bucket: "bucket")
          )
        )
      end
    end

    context "when store does not exist" do
      it "raises StoreNotFoundError" do
        expect { find }.to raise_error(NATS::Object::StoreNotFoundError)
      end
    end
  end

  describe "#create" do
    let(:create) { subject.create(bucket: "bucket") }

    context "when store does not exist" do
      it "creates a store" do
        expect(create).to be_a(NATS::Object::Store).and(
          have_attributes(
            config: have_attributes(bucket: "bucket")
          )
        )
      end
    end

    context "when store already exists" do
      let!(:existing) { subject.create(bucket: "bucket") }

      it "returns the existing store" do
        expect(create.stream.info.created).to eq(existing.stream.info.created)
      end
    end
  end

  describe "#each" do
    let(:each) do
      subject.map do |store|
        {bucket: store.config.bucket}
      end
    end

    context "when no stores exist" do
      it "iterates over an empty array" do
        expect(each).to eq([])
      end
    end

    context "when there are stores" do
      before do
        3.times.map do |index|
          subject.create(bucket: "store_#{index}")
        end
      end

      it "iterates over stores" do
        expect(each).to match_array([
          {bucket: "store_0"},
          {bucket: "store_1"},
          {bucket: "store_2"}
        ])
      end
    end

    context "when there are other streams" do
      before do
        3.times.map do |index|
          js.streams.create(name: "stream_#{index}")
        end

        3.times.map do |index|
          subject.create(bucket: "store_#{index}")
        end
      end

      it "iterates only over stores" do
        expect(each).to match_array([
          {bucket: "store_0"},
          {bucket: "store_1"},
          {bucket: "store_2"}
        ])
      end
    end
  end

  describe "#names" do
    let(:names) { subject.names.map(&:itself) }

    context "when no stores exist" do
      it "iterates over an empty array" do
        expect(names).to eq([])
      end
    end

    context "when there are stores" do
      before do
        3.times.map do |index|
          subject.create(bucket: "store_#{index}")
        end
      end

      it "iterates over stores names" do
        expect(names).to match_array(["store_0", "store_1", "store_2"])
      end
    end

    context "when there are other streams" do
      before do
        3.times.map do |index|
          js.streams.create(name: "stream_#{index}")
        end

        3.times.map do |index|
          subject.create(bucket: "store_#{index}")
        end
      end

      it "iterates only over stores names" do
        expect(names).to match_array(["store_0", "store_1", "store_2"])
      end
    end
  end
end
