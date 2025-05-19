# frozen_string_literal: true

RSpec.describe NATS::JetStream::Consumer::List do
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

  subject { described_class.new(stream) }

  let(:stream) { js.streams.create(name: "stream") }
  let(:js) { NATS.connect.js }

  after { stream.delete }

  describe "#find" do
    let(:find) { subject.find("consumer") }

    context "when consumer exists" do
      before { subject.upsert(name: "consumer") }

      it "returns consumer with the specified name" do
        expect(find).to be_a(NATS::JetStream::Consumer).and(
          be_config(config: {name: "consumer"})
        )
      end
    end

    context "when consumer does not exist" do
      it "raises ConsumerNotFoundError" do
        expect { find }.to raise_error(NATS::JetStream::ConsumerNotFoundError)
      end
    end
  end

  describe "#add" do
    let(:add) { subject.add(name: "consumer") }

    context "when consumer does not exist" do
      it "creates a consumer" do
        expect(add).to be_a(NATS::JetStream::Consumer).and(
          be_config(config: {name: "consumer"})
        )
      end
    end

    context "when consumer already exists" do
      before { subject.upsert(name: "consumer") }

      it "raises ConsumerExistsError" do
        expect { add }.to raise_error(NATS::JetStream::ConsumerExistsError)
      end
    end
  end

  describe "#upsert" do
    let(:upsert) { subject.upsert(name: "consumer") }

    context "when consumer does not exist" do
      it "creates a consumer" do
        expect(upsert).to be_a(NATS::JetStream::Consumer).and(
          be_config(config: {name: "consumer"})
        )
      end
    end

    context "when consumer already exists" do
      let!(:existing) { subject.upsert(name: "consumer") }

      it "returns the existing consumer" do
        expect(upsert.info.created).to eq(existing.info.created)
      end
    end
  end

  describe "#each" do
    let(:each) do
      subject.map do |consumer|
        {name: consumer.config.name}
      end
    end

    context "when there are consumers" do
      before do
        3.times.map do |index|
          subject.upsert(name: "consumer_#{index}")
        end
      end

      it "iterates over consumers" do
        expect(each).to match_array([
          {name: "consumer_0"},
          {name: "consumer_1"},
          {name: "consumer_2"}
        ])
      end
    end

    context "when no consumers exist" do
      it "iterates over an empty array" do
        expect(each).to eq([])
      end
    end
  end

  describe "#names" do
    let(:names) { subject.names.map(&:itself) }

    context "when no consumers exist" do
      it "iterates over an empty array" do
        expect(names).to eq([])
      end
    end

    context "when there are consumers" do
      before do
        3.times.map do |index|
          subject.upsert(name: "consumer_#{index}")
        end
      end

      it "iterates over consumers names" do
        expect(names).to match_array(["consumer_0", "consumer_1", "consumer_2"])
      end
    end
  end
end
