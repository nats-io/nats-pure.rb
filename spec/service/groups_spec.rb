# frozen_string_literal: true

RSpec.describe NATS::Service::Groups do
  before(:all) do
    @server = NatsServerControl.new
    @server.start_server(true)
  end

  after(:all) do
    @server.kill_server
  end

  subject { described_class.new(parent) }

  let(:client) { NATS.connect }
  let(:service) { client.services.add(name: "foo", queue: "default") }
  let(:group) { service.groups.add("bar", queue: "queue") }
  let(:parent) { group }

  describe "#add" do
    context "when queue is specified" do
      let(:add) { subject.add("baz", queue: "qux") }

      it "creates group" do
        expect(add).to be_kind_of(NATS::Service::Group)
          .and have_attributes(name: "baz", subject: "bar.baz", queue: "qux")
      end

      it "sets group attributes" do
        expect(add).to have_attributes(name: "baz", subject: "bar.baz", queue: "qux")
      end

      it "adds group to service.groups" do
        group = add

        expect(service.groups).to include(group)
      end
    end

    context "when queue is not specified" do
      let(:add) { subject.add("baz") }

      it "creates group" do
        expect(add).to be_kind_of(NATS::Service::Group)
      end

      it "sets group attrbiutes" do
        expect(add).to have_attributes(name: "baz", subject: "bar.baz", queue: "queue")
      end

      it "adds group to service.groups" do
        group = add

        expect(service.groups).to include(group)
      end
    end
  end
end
