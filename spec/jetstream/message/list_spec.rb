# frozen_string_literal: true

RSpec.describe NATS::JetStream::Message::List do
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

  let!(:stream) { js.streams.create(name: "stream") }

  let(:client) { NATS.connect }
  let(:js) { client.js }

  after { stream.delete }

  describe "#find" do
    let(:find) { subject.find(params) }

    before do
      stream.publish("data")
      sleep 0.05
    end

    context "when a messages has been found" do
      context "and searched by params[:seq]" do
        let(:params) { {seq: 1} }

        it "returns the message" do
          expect(find).to be_a(NATS::JetStream::StreamMessage).and(
            have_attributes(seq: 1, data: "data")
          )
        end
      end

      context "and searched by params[:last_by_subj]" do
        let(:params) { {last_by_subj: "stream"} }

        it "returns the message" do
          expect(find).to be_a(NATS::JetStream::StreamMessage).and(
            have_attributes(seq: 1, data: "data")
          )
        end
      end

      context "and searched by params[:next_by_subj]" do
        let(:params) { {seq: 1, next_by_subj: "stream"} }

        it "returns the message" do
          expect(find).to be_a(NATS::JetStream::StreamMessage).and(
            have_attributes(seq: 1, data: "data")
          )
        end
      end
    end

    context "when no messages have been found" do
      let(:params) { {seq: 2} }

      it "raises NotFoundErrpr" do
        expect { find }.to raise_error(NATS::JetStream::NotFoundError)
      end
    end
  end
end
