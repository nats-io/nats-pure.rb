# frozen_string_literal: true

require_relative "../pull/handler_examples"

RSpec.describe NATS::JetStream::Fetch::Handler do
  subject { described_class.new(pull) }

  let(:pull) { NATS::JetStream::Fetch.new(consumer, params) }
  let(:params) { {idle_heartbeat: 1.to_nsec / 2} }

  let(:consumer) { NATS::JetStream::Consumer.new(stream, name: "consumer") }
  let(:stream) { NATS::JetStream::Stream.new(js, name: "stream") }

  let(:js) { NATS::JetStream::Context.new(client) }
  let(:client) { double(NATS::Client, new_inbox: "inbox") }

  let(:heartbeats) { pull.heartbeats.send(:task) }

  let(:message) do
    NATS::Msg.new(
      subject: "subject",
      header: header,
      data: "data",
      reply: "$JS.ACK.stream.consumer.3.2795.3495.1744033099995368000.7"
    )
  end

  before do
    pull.heartbeats.start
    allow(pull).to receive(:stop)
  end

  after { pull.heartbeats.stop }

  include_examples "NATS::JetStream::Handler"

  describe "#handle" do
    let(:handle) { subject.handle(message) }

    context "with a consumer message" do
      let(:header) { {} }

      it "resets heartbeat timer" do
        schedule_time = heartbeats.schedule_time

        handle

        expect(heartbeats.schedule_time).to be > schedule_time
      end

      it "increases fetched messages" do
        handle

        expect(pull.buffer.messages_fetched).to eq(1)
      end

      context "when not all messages are fetched yet" do
        it "does not drain pull" do
          handle

          expect(pull).to_not have_received(:stop)
        end
      end

      context "when all messages are fetched" do
        let(:params) { {max_messages: 1} }

        it "drains pull" do
          handle

          expect(pull).to have_received(:stop)
        end
      end
    end

    context "with an idle heartbeat message" do
      let(:header) { {"Status" => "100"} }

      it "resets heartbeat timer" do
        schedule_time = heartbeats.schedule_time

        handle

        expect(heartbeats.schedule_time).to be > schedule_time
      end
    end

    context "with a pull termination message" do
      let(:header) { {"Status" => "408", "Description" => "Request Timeout"} }

      it "drains pull and sets error to message description" do
        handle

        expect(pull).to have_received(:stop).with(
          be_a(NATS::JetStream::PullMessageError).and(
            have_attributes(message: be_a(NATS::JetStream::RequestTimeoutMessage))
          )
        )
      end

      it "drains pull" do
        handle
      end
    end

    context "with an error message" do
      let(:header) { {"Status" => "400", "Description" => "Bad Request"} }

      it "drains pull and sets error to message description" do
        handle

        expect(pull).to have_received(:stop).with(
          be_a(NATS::JetStream::PullMessageError).and(
            have_attributes(message: be_a(NATS::JetStream::BadRequestMessage))
          )
        )
      end
    end
  end
end
