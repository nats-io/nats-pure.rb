# frozen_string_literal: true

RSpec.describe NATS::Object::Watcher do
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

  subject { described_class.new(store, options) }

  let!(:store) { context.stores.create(bucket: "bucket") }
  let(:context) { NATS.connect.object_store }
  let(:options) { {} }

  after { store.delete }

  describe "#updates" do
    after { subject.stop }

    context "when store is empty" do
      before { subject.updates }

      it "returns nil" do
        expect(subject.updates(timeout: 0.1)).to be(nil)
      end
    end

    context "when :updates_only = false" do
      before { store.meta.publish("one", name: "one") }

      let(:options) { {updates_only: false} }

      it "returns initial objects and their updates separated by nil" do
        subject
        sleep 0.05

        store.meta.publish("two", name: "two")

        expect(subject.updates).to have_attributes(name: "one")
        expect(subject.updates).to be_a(NATS::Object::Watcher::Marker)
        expect(subject.updates).to have_attributes(name: "two")
      end
    end

    context "when :updates_only = true" do
      before { store.meta.publish("one", name: "one") }

      let(:options) { {updates_only: true} }

      it "returns only updates" do
        subject

        store.meta.publish("two", name: "two")

        expect(subject.updates).to have_attributes(name: "two")
      end
    end

    context "when :ignore_deletes = false" do
      before { store.meta.publish("one", name: "one", deleted: true) }

      let(:options) { {ignore_deletes: false} }

      it "returns deleted objects" do
        subject

        expect(subject.updates).to have_attributes(name: "one")
      end
    end

    context "when :ignore_deletes = true" do
      before { store.meta.publish("one", name: "one", deleted: true) }

      let(:options) { {ignore_deletes: true} }

      it "does not returns deleted objects" do
        subject

        expect(subject.updates).to be_a(NATS::Object::Watcher::Marker)
      end
    end

    context "when :include_history = false" do
      before do
        store.meta.publish("one", name: "one")
        store.meta.publish("two", name: "two")
      end

      let(:options) { {include_history: false} }

      it "does not include past objects" do
        subject

        expect(subject.updates).to have_attributes(name: "one")
      end
    end

    context "when :include_history = true" do
      before do
        store.meta.publish("one", name: "one")
        store.meta.publish("two", name: "two")
      end

      let(:options) { {include_history: true} }

      it "includes past objects" do
        subject

        expect(subject.updates).to have_attributes(name: "one")
      end
    end
  end

  describe "#stop" do
    let(:consume) { subject.instance_variable_get("@consume") }
    let(:queue) { subject.instance_variable_get("@queue") }

    before { subject }

    it "stops consume" do
      subject.stop

      expect(consume.closed?).to be(true)
    end

    it "closes its queue" do
      subject.stop

      expect(queue.closed?).to be(true)
    end
  end
end
