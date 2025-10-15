# frozen_string_literal: true

RSpec.describe NATS::JetStream::Info do
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

  describe "#initialize" do
    subject { described_class.new(info) }

    let(:info) do
      {
        memory: 700,
        storage: 500,
        streams: 7,
        consumers: 5,
        domain: "domain",
        limits: {
          max_memory: 70,
          max_storage: 500,
          max_streams: 40,
          max_consumers: 10,
          max_bytes_required: true,
          max_ack_pending: 300,
          memory_max_stream_bytes: 500,
          storage_max_stream_bytes: 700
        },
        tiers: {
          memory: 500,
          storage: 300,
          streams: 10,
          consumers: 5,
          limits: {
            max_memory: 50,
            max_storage: 100,
            max_streams: 30,
            max_consumers: 40,
            max_bytes_required: true,
            max_ack_pending: 500,
            memory_max_stream_bytes: 300,
            storage_max_stream_bytes: 400
          }
        },
        api: {
          total: 50,
          errors: 7
        }
      }
    end

    it "sets attributes" do
      expect(subject).to be_config(info)
    end
  end

  describe "server response" do
    subject { js.info }

    let(:js) { NATS.connect.js }

    it "returns info" do
      expect(subject).to have_attributes(
        memory: be_a(Integer),
        storage: be_a(Integer),
        streams: be_a(Integer),
        consumers: be_a(Integer),
        domain: nil,
        limits: have_attributes(
          max_memory: -1,
          max_storage: -1,
          max_streams: -1,
          max_consumers: -1,
          max_bytes_required: false,
          max_ack_pending: -1,
          memory_max_stream_bytes: -1,
          storage_max_stream_bytes: -1
        ),
        tiers: nil,
        api: have_attributes(
          total: be_a(Integer),
          errors: be_a(Integer)
        )
      )
    end
  end
end
