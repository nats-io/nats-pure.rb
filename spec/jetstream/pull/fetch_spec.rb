# frozen_string_literal: true

require_relative "pull_examples"

RSpec.describe NATS::JetStream::Fetch do
  before(:all) do
    @server = NatsServerControl.new("nats://127.0.0.1:4222", "/tmp/test-nats.pid", "-js")
    @server.start_server(true)
  end

  after(:all) do
    @server.kill_server
  end

  subject { described_class.new(consumer, params, &block) }

  let(:block) { ->(message) { message } }
  let(:params) { {expires: 1.to_nsec} }

  let(:consumer) { stream.consumers.upsert(name: "consumer") }
  let!(:stream) { js.streams.create(name: "stream") }

  let(:js) { NATS::JetStream::Context.new(client) }
  let(:client) { NATS.connect }

  after { stream.delete }

  include_examples "NATS::JetStream::Pull"

  describe "#wait" do
    before do
      3.times do |index|
        js.publish("stream", "data_#{index}")
      end

      subject.start
    end

    after do
      first_seq = stream.info.state.first_seq

      3.times do |index|
        stream.messages.find(seq: first_seq + index).delete
      end
    end

    context "when fetch does not take too long to finish" do
      let(:params) { {max_messages: 3, expires: 1.to_nsec} }

      it "waits until the fetch is finished" do
        subject.wait

        expect(subject.messages).to match(
          [
            have_attributes(data: "data_0"),
            have_attributes(data: "data_1"),
            have_attributes(data: "data_2")
          ]
        )
      end
    end

    context "when fetch takes too long to finish" do
      let(:params) { {max_messages: 100, expires: 1.to_nsec} }

      it "stops the fetch after expires time has passed" do
        subject.wait

        expect(subject.last_error).to eq("Request Timeout")
      end
    end
  end
end
