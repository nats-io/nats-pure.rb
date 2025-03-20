# frozen_string_literal: true

RSpec.describe NATS::JetStream::Context do
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

  subject { described_class.new(client, params) }

  let(:params) { {} }
  let(:client) { NATS.connect }

  describe "#initialize" do
    context "with :prefix" do
      let(:params) { {prefix: "$PREFIX"} }

      it "initializes with the specified prefix" do
        expect(subject.api.subject).to eq("$PREFIX")
      end
    end

    context "without params" do
      it "initializes with default prefix" do
        expect(subject.api.subject).to eq("$JS.API")
      end
    end
  end

  describe "#streams" do
    it "returns Stream::List" do
      expect(subject.streams).to be_a(NATS::JetStream::Stream::List)
    end
  end

  describe "#info" do
    it "returns JS info" do
      expect(subject.info).to be_a(NATS::JetStream::Info)
    end
  end

  describe "#publish" do
    let(:publish) { subject.publish("stream", "data", options) }

    let!(:stream) { subject.streams.create(name: "stream") }

    context "with options" do
      let(:options) { {stream: "stream"} }

      after { stream.delete }

      it "publishes a message to the stream" do
        expect(publish).to have_attributes(stream: "stream", seq: be_a(Integer))
      end
    end

    context "without options" do
      let(:options) { {} }

      after { stream.delete }

      it "publishes a message to the stream" do
        expect(publish).to have_attributes(stream: "stream", seq: be_a(Integer))
      end
    end

    context "when stream does not exist" do
      let(:options) { {} }

      before { stream.delete }

      it "raises NATS::JetStream::NoStreamResponseError" do
        expect { publish }.to raise_error(NATS::JetStream::NoStreamResponseError)
      end
    end
  end
end
