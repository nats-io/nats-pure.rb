# frozen_string_literal: true

RSpec.describe NATS::JetStream::Stream::List do
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

  subject { described_class.new(js) }

  let(:js) { NATS.connect.js }

  describe "#find" do
    let(:find) { subject.find("stream") }

    context "when stream exists" do
      let!(:stream) { subject.create(name: "stream") }

      after { stream.delete }

      it "returns stream with the specified name" do
        expect(find).to be_a(NATS::JetStream::Stream).and(
          have_attributes(
            config: have_attributes(name: "stream")
          )
        )
      end
    end

    context "when stream does not exist" do
      it "raises NotFoundError" do
        expect { find }.to raise_error(NATS::JetStream::StreamNotFoundError)
      end
    end
  end

  describe "#add" do
    let(:add) { subject.add(name: "stream") }

    after { add.delete }

    context "when stream does not exist" do
      it "creates a stream" do
        expect(add).to be_a(NATS::JetStream::Stream).and(
          have_attributes(
            config: have_attributes(name: "stream")
          )
        )
      end
    end

    context "when stream already exists" do
      let!(:existing) { subject.add(name: "stream") }

      it "returns the existing stream" do
        expect(add.info.created).to eq(existing.info.created)
      end
    end
  end

  describe "#each" do
    let(:each) do
      subject.map do |stream|
        {name: stream.config.name}
      end
    end

    context "when there are streams" do
      before do
        3.times.map do |index|
          subject.create(name: "stream_#{index}")
        end
      end

      after { js.streams.each(&:delete) }

      it "iterates over streams" do
        expect(each).to match_array([
          {name: "stream_0"},
          {name: "stream_1"},
          {name: "stream_2"}
        ])
      end
    end

    context "when no streams exist" do
      it "iterates over an empty array" do
        expect(each).to eq([])
      end
    end
  end

  describe "#names" do
    let(:names) { subject.names.map(&:itself) }

    context "when no streams exist" do
      it "iterates over an empty array" do
        expect(names).to eq([])
      end
    end

    context "when there are streams" do
      before do
        3.times.map do |index|
          subject.create(name: "stream_#{index}")
        end
      end

      after { js.streams.each(&:delete) }

      it "iterates over streams names" do
        expect(names).to match_array(["stream_0", "stream_1", "stream_2"])
      end
    end
  end
end
