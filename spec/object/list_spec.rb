# frozen_string_literal: true

RSpec.describe NATS::Object::List do
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

  describe "#each" do
    let(:each) do
      subject.map do |object|
        {name: object.info.name}
      end
    end

    context "when store does not have any objects" do
      it "iterates over an empty array" do
        expect(each).to eq([])
      end
    end

    describe "with options[:show_deleted]" do
      before do
        3.times do |index|
          name = "object_#{index}"
          store.meta.publish(name, name: name)
        end

        3.times do |index|
          name = "object_#{index + 3}"
          store.meta.publish(name, name: name, deleted: true)
        end
      end

      context "and show_deleted = false" do
        let(:options) { {show_deleted: false} }

        it "excludes deleted objects" do
          expect(each).to match_array([
            {name: "object_0"},
            {name: "object_1"},
            {name: "object_2"}
          ])
        end
      end

      context "and show_deleted = true" do
        let(:options) { {show_deleted: true} }

        it "includes deleted objects" do
          expect(each).to match_array([
            {name: "object_0"},
            {name: "object_1"},
            {name: "object_2"},
            {name: "object_3"},
            {name: "object_4"},
            {name: "object_5"}
          ])
        end
      end
    end

    context "when some objects are updated during iteration" do
      before do
        3.times do |index|
          name = "object_#{index}"
          store.meta.publish(name, name: name)
        end
      end

      let(:each) do
        subject.map do |object|
          store.meta.publish(
            object.info.name,
            object.info.update(description: "description")
          )

          {name: object.info.name}
        end
      end

      it "includes only one instance for every object" do
        expect(each).to match_array([
          {name: "object_0"},
          {name: "object_1"},
          {name: "object_2"}
        ])
      end
    end
  end
end
