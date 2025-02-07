# frozen_string_literal: true

RSpec.describe NATS::JetStream::Consumer do
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

  subject { stream.consumers.upsert(name: "consumer") }

  let(:stream) { js.streams.create(name: "stream") }
  let(:js) { NATS.connect.js }

  after { stream.delete }

  describe "#config" do
    it "returns config" do
      expect(subject.config).to be_a(NATS::JetStream::Consumer::Config)
    end
  end

  describe "#info" do
    it "returns info" do
      expect(subject.info).to be_a(NATS::JetStream::Consumer::Info)
    end
  end

  describe "#subject" do
    it "returns consumer subject" do
      expect(subject.subject).to eq("stream.consumer")
    end
  end

  describe "#update" do
    let(:update) { subject.update(description: "description") }

    it "updates consumer" do
      update

      expect(subject.config.description).to eq("description")
    end
  end

  describe "#delete" do
    context "when consumer still exists" do
      it "deletes consumer" do
        subject.delete

        expect { stream.consumers.find("consumer") }.to raise_error(NATS::JetStream::ConsumerNotFoundError)
      end

      it "returns true" do
        expect(subject.delete).to be(true)
      end
    end

    context "when consumer has been deleted" do
      before { subject.delete }

      it "raise ConsumerNotFoundError" do
        expect { subject.delete }.to raise_error(NATS::JetStream::ConsumerNotFoundError)
      end
    end
  end

  describe "#fetch" do
    let(:fetch) { subject.fetch(max_messages: 5, expires: 1.to_nsec) }

    it "returns Consumer::Fetch" do
      expect(fetch).to be_a(NATS::JetStream::Consumer::Fetch).and(
        having_attributes(params: {max_messages: 5, expires: 1.to_nsec})
      )
    end
  end

  describe "#next" do
    let(:next_message) { subject.next(expires: 1.to_nsec) }

    context "when there are messages in the stream" do
      before do
        stream.publish("data")
        sleep 0.05
      end

      it "returns the next message" do
        expect(next_message).to be_a(NATS::JetStream::ConsumerMessage).and(
          have_attributes(data: "data")
        )
      end
    end

    context "when there are no messages in the stream" do
      it "returns nil" do
        expect(next_message).to be_nil
      end
    end
  end

  describe "#consume" do
    let(:consume) { subject.consume(max_messages: 5) }

    it "returns Consume" do
      expect(consume).to be_a(NATS::JetStream::Consume).and(
        be_config(config: {max_messages: 5})
      )
    end
  end
end
