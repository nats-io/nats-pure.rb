# frozen_string_literal: true

require_relative "pull/pull_examples"

RSpec.describe NATS::JetStream::Consume do
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

  subject { described_class.new(consumer, params, &block) }

  let(:block) { ->(message) { message } }
  let(:params) { {} }

  let(:consumer) { stream.consumers.upsert(name: "consumer") }
  let(:stream) { js.streams.create(name: "stream") }

  let(:js) { NATS::JetStream::Context.new(client) }
  let(:client) { NATS.connect }

  after do
    consumer.delete
    stream.delete
  end

  include_examples "NATS::JetStream::Pull", idle_heartbeat: 15.to_nsec
end
