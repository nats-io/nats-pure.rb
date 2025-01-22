# frozen_string_literal: true

require_relative "extension_examples"

RSpec.describe NATS::Service::Group do
  subject { described_class.new(name: name, parent: service, queue: queue) }

  let(:name) { "bar" }
  let(:queue) { "queue" }

  let(:client) { NATS.connect }
  let(:service) { client.add_service(name: "foo", queue: "default") }

  before(:all) do
    @server = NatsServerControl.new
    @server.start_server(true)
  end

  after(:all) do
    @server.kill_server
  end

  after { service.stop }

  include_examples "extension"

  describe "#initialize" do
    it "sets name" do
      expect(subject.name).to eq("bar")
    end

    it "builds subject" do
      expect(subject.subject).to eq("foo.bar")
    end

    it "sets queue" do
      expect(subject.queue).to eq("queue")
    end

    context "when name is invalid" do
      let(:name) { "$%^&" }

      it "raises InvalidNameError" do
        expect { subject }.to raise_error(NATS::Service::InvalidNameError)
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
