# frozen_string_literal: true

RSpec.describe NATS::JetStream::Publisher do
  subject { described_class.new(js) }

  let(:js) { NATS::JetStream::Context.new(client) }
  let(:client) { double(NATS::Client, request: response) }

  describe "#publish" do
    let(:response) do
      NATS::Msg.new(data: {stream: "stream", seq: 5}.to_json)
    end

    let(:publish) { subject.publish("stream", "data", options) }

    context "without options" do
      let(:options) { {message_id: "9f01"} }
      let(:options) { {} }

      it "makes a publish request without options" do
        publish

        expect(client).to have_received(:request).with(
          "stream", "data", header: {}, timeout: nil
        )
      end
    end

    context "with headers" do
      let(:options) { {message_id: "9f01"} }

      it "sets header for the publish request" do
        publish

        expect(client).to have_received(:request).with(
          "stream", "data", header: {"Nats-Msg-Id" => "9f01"}, timeout: nil
        )
      end
    end

    context "with :timeout" do
      let(:options) { {timeout: 1} }

      it "sets timeout for the publish request" do
        publish

        expect(client).to have_received(:request).with(
          "stream", "data", header: {}, timeout: 1
        )
      end
    end

    context "when an error occurs" do
      let(:response) do
        NATS::Msg.new(
          data: {
            error: {code: 404, err_code: 10059}
          }.to_json
        )
      end

      let(:options) { {} }

      it "raises a response error" do
        expect { publish }.to raise_error(NATS::JetStream::StreamNotFoundError)
      end
    end
  end
end
