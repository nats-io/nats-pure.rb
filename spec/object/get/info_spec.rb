# frozen_string_literal: true

RSpec.describe NATS::Object::Get::Info do
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

  describe "#find" do
    let(:find) { subject.find("name", options) }
    let(:options) { NATS::Object::Get::Options.new(show_deleted: show_deleted) }
    let(:show_deleted) { false }

    context "when info exists" do
      before { store.meta.publish("name", name: "name") }

      it "returns info" do
        expect(find).to be_a(NATS::Object::Info)
        expect(find.name).to eq("name")
      end
    end

    context "when info does not exist" do
      it "raises ObjectNotFoundError" do
        expect { find }.to raise_error(NATS::Object::ObjectNotFoundError)
      end
    end

    context "when info is deleted" do
      before { store.meta.publish("name", name: "name", deleted: true) }

      context "and options[:show_deleted] = false" do
        let(:show_deleted) { false }

        it "raises ObjectNotFoundError" do
          expect { find }.to raise_error(NATS::Object::ObjectNotFoundError)
        end
      end

      context "and options[:show_deleted] = true" do
        let(:show_deleted) { true }

        it "returns info" do
          expect(find).to be_a(NATS::Object::Info)
          expect(find.name).to eq("name")
        end
      end
    end
  end
end
