# frozen_string_literal: true

RSpec.describe NATS::Object::Link do
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

  describe "#link" do
    let(:object) { store.put(name: "object", data: "data") }
    let(:other_object) { store.put(name: "other", data: "data") }

    let(:link) { subject.link("link", object) }

    context "when linking to a non-existing object" do
      before do
        object
        store.stream.purge
      end

      it "raises ObjectNotFoundError" do
        expect { link }.to raise_error(NATS::Object::ObjectNotFoundError)
      end
    end

    context "when linking to a deleted object" do
      before { object.delete }

      it "raises ObjectDeletedError" do
        expect { link }.to raise_error(NATS::Object::ObjectDeletedError)
      end
    end

    context "when linking to a link" do
      let(:object) { subject.link("object", other_object) }

      it "raises NoLinkToLinkError" do
        expect { link }.to raise_error(NATS::Object::NoLinkToLinkError)
      end
    end

    context "when link object is not a link" do
      before { store.put(name: "link", data: "data") }

      it "raises ObjectExistsError" do
        expect { link }.to raise_error(NATS::Object::ObjectExistsError)
      end
    end

    context "when link object is a link" do
      before { subject.link("link", other_object) }

      it "returns Object" do
        expect(link).to be_a(NATS::Object)
      end

      it "replaces the object info" do
        expect(link.info).to have_attributes(
          name: "link",
          bucket: "bucket",
          options: have_attributes(
            link: have_attributes(bucket: "bucket", name: "object"),
            max_chunk_size: 131072
          ),
          chunks: 0,
          size: 0,
          digest: "",
          deleted: false
        )
      end
    end

    context "when link object does not exist" do
      it "returns Object" do
        expect(link).to be_a(NATS::Object)
      end

      it "publishes the object info" do
        expect(link.info).to have_attributes(
          name: "link",
          bucket: "bucket",
          options: have_attributes(
            link: have_attributes(bucket: "bucket", name: "object"),
            max_chunk_size: 131072
          ),
          chunks: 0,
          size: 0,
          digest: "",
          deleted: false
        )
      end
    end
  end
end
