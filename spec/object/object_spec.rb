# frozen_string_literal: true

RSpec.describe NATS::Object do
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

  subject { store.put(name: "object", data: "data") }

  let!(:store) { context.stores.create(bucket: "bucket") }
  let(:context) { NATS.connect.object_store }

  after { store.stream.delete }

  describe "#info" do
    it "returns info" do
      expect(subject.info).to be_a(NATS::Object::Info)
    end
  end

  describe "#update" do
    it "deletes object" do
      subject.update(description: "description")
      subject.reload

      expect(subject.info.description).to eq("description")
    end
  end

  describe "#delete" do
    it "deletes object" do
      subject.delete
      subject.reload

      expect(subject.deleted?).to be(true)
    end
  end

  describe "#deleted?" do
    context "when object is deleted" do
      before { subject.delete }

      it "returns true" do
        expect(subject.deleted?).to be(true)
      end
    end

    context "when object is present" do
      it "returns false" do
        expect(subject.deleted?).to be(false)
      end
    end
  end

  describe "#reload" do
    context "when object does not exist" do
      before do
        subject
        store.meta.purge("object")
      end

      it "raises ObjectNotFoundError" do
        expect { subject.reload }.to raise_error(NATS::Object::ObjectNotFoundError)
      end
    end

    context "when object still exists" do
      before do
        store.meta.publish("object", {**subject.info, description: "description"})
      end

      it "reloads object info" do
        subject.reload

        expect(subject.info.description).to eq("description")
      end
    end
  end

  describe "#link?" do
    context "when object is a link" do
      let(:object) { store.put(name: "link", data: "data") }

      subject { store.link(name: "object", to: object) }

      it "returns true" do
        expect(subject.link?).to be(true)
      end
    end

    context "when object is not a link" do
      it "returns false" do
        expect(subject.link?).to be(false)
      end
    end
  end
end
