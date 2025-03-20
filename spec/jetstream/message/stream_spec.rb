# frozen_string_literal: true

RSpec.describe NATS::JetStream::StreamMessage do
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

  subject { stream.messages.find(seq: 1) }

  let!(:stream) { js.streams.create(name: "stream") }
  let(:js) { NATS.connect.js }

  before { js.publish("stream", "data") }

  after { stream.delete }

  describe "#initialize" do
    it "sets message attributes" do
      expect(subject).to have_attributes(
        subject: "stream",
        data: "data",
        seq: 1,
        time: be_a(Time)
      )
    end
  end

  describe "#delete" do
    context "when message still exists" do
      it "deletes message" do
        subject.delete

        expect { stream.messages.find(seq: 1) }.to raise_error(NATS::JetStream::MessageNotFoundError)
      end

      it "returns true" do
        expect(subject.delete).to be(true)
      end
    end

    context "when messages has been deleted" do
      before { subject.delete }

      it "raise ServerError" do
        expect { subject.delete }.to raise_error(NATS::JetStream::ServerError)
      end
    end
  end
end
