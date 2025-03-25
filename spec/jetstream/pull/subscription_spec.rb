# frozen_string_literal: true

RSpec.describe NATS::JetStream::Pull::Subscription do
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

  subject { pull.subscription }

  let(:pull) { NATS::JetStream::Fetch.new(consumer) }
  let(:consumer) { stream.consumers.upsert(name: "consumer") }
  let(:stream) { js.streams.create(name: "stream") }

  let(:js) { NATS::JetStream::Context.new(client) }
  let(:client) { NATS.connect }

  before do
    allow(pull.handler).to receive(:handle).and_call_original
  end

  after do
    consumer.delete
    stream.delete
  end

  describe "#inbox" do
    it "generates subscription inbox" do
      expect(subject.inbox).to match(/_INBOX.\w+/)
    end
  end

  describe "#start" do
    after { pull.drain }

    context "when no errors occur" do
      let(:pull) do
        consumer.consume { |message| message }
      end

      it "processes an incoming message" do
        subject.start

        js.publish("stream", "data")
        sleep 0.25

        expect(pull.handler).to have_received(:handle).at_least(1)
      end
    end

    context "when an error occurs" do
      let(:pull) do
        consumer.consume do |message|
          raise StandardError
        end
      end

      it "handles the error" do
        subject.start

        js.publish("stream", "data")
        sleep 0.25

        expect(pull.error).to be_a(StandardError)
        expect(pull.closed?).to be(true)
      end
    end
  end

  describe "#drain" do
    before { subject.start }

    let(:subs) { client.instance_variable_get("@subs") }

    it "drains the subscription" do
      subject.drain

      expect(subs.values).to include(
        having_attributes(subject: subject.inbox, drained: true)
      )
    end
  end
end
