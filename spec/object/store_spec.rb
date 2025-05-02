# frozen_string_literal: true

RSpec.describe NATS::Object::Store do
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

  subject! { context.stores.create(bucket: "bucket") }

  let(:context) { NATS.connect.object_store }

  after {
    begin
      subject.delete
    rescue
      nil
    end
  }

  describe "#config" do
    it "returns config" do
      expect(subject.config).to be_a(NATS::Object::Store::Config)
    end
  end

  describe "#status" do
    it "returns status" do
      expect(subject.status).to be_a(NATS::Object::Store::Status)
    end
  end

  describe "#stream" do
    it "returns the underlying stream" do
      expect(subject.stream).to be_a(NATS::JetStream::Stream)
    end
  end

  describe "#put" do
    let(:put) { subject.put(name: "string", data: "string") }

    it "creates an object" do
      expect(put).to be_a(NATS::Object).and(
        have_attributes(
          info: have_attributes(name: "string")
        )
      )
    end
  end

  describe "#get" do
    before { subject.put(name: "string", data: "string") }

    let(:get) { subject.get("string") }

    it "retrieves an object" do
      expect(get).to be_a(NATS::Object).and(
        have_attributes(
          info: have_attributes(name: "string")
        )
      )
    end
  end

  describe "#link" do
    let(:object) { subject.put(name: "object", data: "data") }
    let(:link) { subject.link(name: "link", to: object) }

    it "creates a link to an object" do
      expect(link).to be_a(NATS::Object).and(
        have_attributes(
          info: have_attributes(
            name: "link",
            options: have_attributes(
              link: have_attributes(bucket: "bucket", name: "object")
            )
          )
        )
      )
    end
  end

  describe "#update" do
    let(:update) { subject.update(description: "description") }

    it "updates stream" do
      update

      expect(subject.config.description).to eq("description")
    end
  end

  describe "#seal" do
    context "when store is active" do
      it "seals store" do
        subject.seal

        expect(subject.sealed?).to be(true)
      end
    end

    context "when store is sealed" do
      before { subject.seal }

      it "seals store" do
        expect { subject.seal }.to raise_error(NATS::Object::StoreSealedError)
      end
    end
  end

  describe "#sealed?" do
    context "when store is sealed" do
      before { subject.seal }

      it "returns true" do
        expect(subject.sealed?).to be(true)
      end
    end

    context "when store is not sealed" do
      it "returns false" do
        expect(subject.sealed?).to be(false)
      end
    end
  end

  describe "#delete" do
    context "when store still exists" do
      it "deletes store" do
        subject.delete

        expect { context.stores.find("bucket") }.to raise_error(NATS::Object::StoreNotFoundError)
      end

      it "returns true" do
        expect(subject.delete).to be(true)
      end
    end

    context "when store has been deleted" do
      before { subject.delete }

      it "raise StoreNotFoundError" do
        expect { subject.delete }.to raise_error(NATS::Object::StoreNotFoundError)
      end
    end
  end

  describe "#deleted?" do
    context "when store is deleted" do
      before { subject.delete }

      it "returns true" do
        expect(subject.deleted?).to be(true)
      end
    end

    context "when store is present" do
      it "returns false" do
        expect(subject.deleted?).to be(false)
      end
    end
  end

  describe "#watch" do
    let(:watch) { subject.watch(ignore_deletes: false) }

    after { watch.stop }

    it "returns a watcher" do
      expect(watch).to be_a(NATS::Object::Watcher)
      expect(watch.options).to have_attributes(ignore_deletes: false)
    end
  end

  describe "#objects" do
    let(:objects) { subject.objects(show_deleted: true) }

    it "returns Object::List" do
      expect(objects).to be_a(NATS::Object::List)
      expect(objects.options).to include(show_deleted: true)
    end
  end
end
