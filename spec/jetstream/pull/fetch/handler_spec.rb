# frozen_string_literal: true

require_relative "../handler_examples"

RSpec.describe NATS::JetStream::Fetch::Handler do
  subject { described_class.new(pull) }

  let(:pull) { NATS::JetStream::Fetch.new(consumer, params) }
  let(:params) { {idle_heartbeat: 1.to_nsec / 2} }

  let(:consumer) { NATS::JetStream::Consumer.new(stream, name: "consumer") }
  let(:stream) { NATS::JetStream::Stream.new(js, name: "stream") }

  let(:js) { NATS::JetStream::Context.new(client) }
  let(:client) { double(NATS::Client, new_inbox: "inbox") }

  let(:heartbeats) { pull.monitor.heartbeats }

  let(:message) do
    NATS::Msg.new(
      subject: "subject",
      header: header,
      data: "data",
      reply: "inbox"
    )
  end

  before do
    pull.monitor.start
    allow(pull).to receive(:drain)
  end

  after { pull.monitor.stop }

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

          expect(pull).to_not have_received(:drain)
        end
      end

      context "when all messages are fetched" do
        let(:params) { {max_messages: 1} }

        it "drains pull" do
          handle

          expect(pull).to have_received(:drain)
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

      it "sets error to message description" do
        handle

        expect(pull.last_error).to eq("Request Timeout")
      end

      it "drains pull" do
        handle

        expect(pull).to have_received(:drain)
      end
    end

    context "with an error message" do
      let(:header) { {"Status" => "400", "Description" => "Bad Request"} }

      it "sets error to message description" do
        handle

        expect(pull.last_error).to eq("Bad Request")
      end

      it "drains pull" do
        handle

        expect(pull).to have_received(:drain)
      end
    end
  end
end
