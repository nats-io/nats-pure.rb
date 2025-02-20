# frozen_string_literal: true

RSpec.describe NATS::Services do
  before(:all) do
    @server = NatsServerControl.new
    @server.start_server(true)
  end

  after(:all) do
    @server.kill_server
  end

  subject { described_class.new(client) }

  let(:client) { NATS.connect }

  describe "#add" do
    let(:add) { subject.add(name: "foo", queue: "default") }

    it "creates services" do
      expect(add).to be_kind_of(NATS::Service)
    end

    it "sets service attributes" do
      expect(add).to have_attributes(name: "foo", queue: "default")
    end
  end
end
