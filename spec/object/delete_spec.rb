# frozen_string_literal: true

RSpec.describe NATS::Object::Delete do
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

  describe "#delete" do
    let(:delete) { subject.delete(object) }
    let(:object) { store.put(name: "object", data: "data") }

    context "when object does not exists" do
      before do
        object
        store.meta.purge("object")
      end

      it "raises ObjectNotFoundError" do
        expect { delete }.to raise_error(NATS::Object::ObjectNotFoundError)
      end
    end

    context "when object is deleted" do
      before { object.delete }

      it "raises ObjectDeletedError" do
        expect { delete }.to raise_error(NATS::Object::ObjectDeletedError)
      end
    end

    context "when object exists" do
      let(:chunks) { store.chunks.find(object.info.nuid) }

      it "marks it as deleted" do
        delete

        expect(object.reload.deleted?).to be(true)
      end

      it "deletes all its chunks" do
        delete

        expect(chunks).to be(nil)
      end
    end
  end
end
