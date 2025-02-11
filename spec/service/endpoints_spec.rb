# frozen_string_literal: true

RSpec.describe NATS::Service::Endpoints do
  before(:all) do
    @server = NatsServerControl.new
    @server.start_server(true)
  end

  after(:all) do
    @server.kill_server
  end

  subject { described_class.new(group) }

  let(:client) { NATS.connect }
  let(:service) { client.services.add(name: "foo", queue: "default") }
  let(:group) { service.groups.add("bar", queue: "queue") }

  describe "#add" do
    context "when options are specified" do
      let(:add) { subject.add("baz", queue: "qux") }

      it "creates endpoint" do
        expect(add).to be_kind_of(NATS::Service::Endpoint)
      end

      it "sets endpoint attributes" do
        expect(add).to have_attributes(name: "baz", subject: "bar.baz", queue: "qux")
      end

      it "adds endpoint to service.endpoints" do
        endpoint = add

        expect(service.endpoints).to include(endpoint)
      end
    end

    context "when options are not specified" do
      let(:add) { subject.add("baz") }

      it "creates endpoint" do
        expect(add).to be_kind_of(NATS::Service::Endpoint)
      end

      it "sets endpoint attributes" do
        expect(add).to have_attributes(name: "baz", subject: "bar.baz", queue: "queue")
      end

      it "adds endpoint to service.endpoints" do
        endpoint = add

        expect(service.endpoints).to include(endpoint)
      end
    end
  end
end
