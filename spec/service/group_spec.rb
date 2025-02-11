# frozen_string_literal: true

RSpec.describe NATS::Service::Group do
  subject { described_class.new(name: name, parent: parent, queue: queue) }

  let(:name) { "bar" }
  let(:queue) { "queue" }

  let(:client) { NATS.connect }
  let(:service) { client.services.add(name: "foo", queue: "default") }
  let(:parent) { service }

  before(:all) do
    @server = NatsServerControl.new
    @server.start_server(true)
  end

  after(:all) do
    @server.kill_server
  end

  after do
    service.stop
    client.close
  end

  describe "#initialize" do
    context "when name is valid" do
      it "sets name" do
        expect(subject.name).to eq("bar")
      end
    end

    context "when name is invalid" do
      let(:name) { "$%^&" }

      it "raises InvalidNameError" do
        expect { subject }.to raise_error(NATS::Service::InvalidNameError)
      end
    end

    context "when parent is a service" do
      it "sets subject to name" do
        expect(subject.subject).to eq("bar")
      end
    end

    context "when parent is a group" do
      let(:parent) { service.groups.add("baz") }

      it "builds subject based on group.subject" do
        expect(subject.subject).to eq("baz.bar")
      end
    end

    context "when queue is valid" do
      it "sets queue" do
        expect(subject.queue).to eq("queue")
      end
    end

    context "when queue is blank" do
      let(:queue) { nil }

      it "sets queue to parent.queue" do
        expect(subject.queue).to eq("default")
      end
    end

    context "when queue is invalid" do
      let(:queue) { ">queue" }

      it "raises InvalidQueueError" do
        expect { subject }.to raise_error(NATS::Service::InvalidQueueError)
      end
    end
  end
end
