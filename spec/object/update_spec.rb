# frozen_string_literal: true

RSpec.describe NATS::Object::Update do
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

  describe "#update" do
    let(:update) { subject.update(object, meta) }

    let(:object) { store.put(name: "object", data: "data") }
    let(:meta) { {description: "description"} }

    context "when object does not exists" do
      before do
        object
        store.meta.purge("object")
      end

      it "raises ObjectNotFoundError" do
        expect { update }.to raise_error(NATS::Object::ObjectNotFoundError)
      end
    end

    context "when object is deleted" do
      before { object.delete }

      it "raises ObjectDeletedError" do
        expect { update }.to raise_error(NATS::Object::ObjectDeletedError)
      end
    end

    context "when options contain :name" do
      let(:meta) { {name: "other"} }

      context "and there is an object with the same name" do
        before { store.put(name: "other", data: "data") }

        it "raises NameTakenError" do
          expect { update }.to raise_error(NATS::Object::NameTakenError)
        end
      end

      context "and there is no objects with the same name" do
        it "updates object" do
          update

          expect(object.info.name).to eq("other")
        end

        it "removes the original object" do
          update

          expect { store.get("object") }.to raise_error(NATS::Object::ObjectNotFoundError)
        end
      end
    end

    context "when options contain other values" do
      let(:options) { {description: "description"} }

      before { Timecop.freeze(Time.new(2025, 5, 1)) }
      after { Timecop.return }

      it "updates object" do
        update

        expect(object.reload.info.description).to eq("description")
      end

      it "sets mtime to Time.now" do
        update

        expect(object.info.mtime).to eq(Time.new(2025, 5, 1))
      end
    end
  end
end
