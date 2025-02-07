# frozen_string_literal: true

RSpec.describe NATS::JetStream::Consumer::Fetch do
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

  subject { described_class.new(consumer, params) }

  let(:params) { {max_messages: 3, expires: 1.to_nsec} }
  let(:consumer) { stream.consumers.upsert(name: "consumer") }
  let(:stream) { js.streams.create(name: "stream") }
  let(:js) { NATS.connect.js }

  after do
    consumer.delete
    stream.delete
  end

  describe "#each" do
    let(:each) { subject.map(&:data) }

    before do
      allow_any_instance_of(NATS::JetStream::Fetch).to receive(:start).and_call_original
    end

    context "when messages have not been fetched yet" do
      it "starts a new fetch" do
        each

        expect(subject.fetch).to have_received(:start)
      end

      context "and there are enough messages in the stream" do
        before do
          3.times { |index| stream.publish("data_#{index}") }
        end

        it "iterates over messages" do
          expect(each).to match_array(["data_0", "data_1", "data_2"])
        end
      end

      context "and there are not enough messages in the stream" do
        before do
          3.times { |index| stream.publish("data_#{index}") }
        end

        let(:params) { {max_messages: 6, expires: 1.to_nsec} }

        it "iterates over fetched messages" do
          expect(each).to match_array(["data_0", "data_1", "data_2"])
        end
      end

      context "and stream does not have any messages" do
        it "iterates over an empty array" do
          expect(each).to match_array([])
        end
      end
    end

    context "when messages have been already fetched" do
      before do
        3.times { |index| stream.publish("data_#{index}") }
      end

      before { subject.each(&:data) }

      it "does not start a new fetch" do
        each

        expect(subject.fetch).to have_received(:start).once
      end

      it "iterates over messages" do
        expect(each).to match_array(["data_0", "data_1", "data_2"])
      end
    end
  end
end
