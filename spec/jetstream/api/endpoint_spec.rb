# frozen_string_literal: true

RSpec.describe NATS::JetStream::Api::Endpoint do
  subject(:endpoint) do
    described_class.new(
      parent: parent,
      name: name,
      request: request,
      response: response
    )
  end

  let(:api) { NATS::JetStream::Api.new(jetstream) }
  let(:jetstream) { NATS::JetStream::Context.new(client) }

  let(:parent) { api }
  let(:name) { :info }
  let(:response) { NATS::JetStream::Api::AccountInfoResponse }
  let(:request) { NATS::JetStream::Api::Request }

  let(:client) do
    double(NATS::Client, request: reply, publish: nil)
  end

  let(:reply) do
    NATS::Msg.new(data: {streams: 5, consumers: 10}.to_json)
  end

  describe "#call" do
    let(:call) { endpoint.call(subject, data, params) }

    let(:subject) { "consumer" }
    let(:data) { {} }
    let(:params) { {} }

    context "when parent is a group" do
      let(:parent) do
        NATS::JetStream::Api::Group.new(parent: api, name: :stream)
      end

      it "makes a request using group.subject" do
        call

        expect(client).to have_received(:request).with(
          "$JS.API.STREAM.INFO.consumer", "{}"
        )
      end
    end

    context "when parent is API" do
      let(:parent) { api }

      it "makes a request with API subject" do
        call

        expect(client).to have_received(:request).with(
          "$JS.API.INFO.consumer", "{}"
        )
      end
    end

    context "when response is defined" do
      let(:response) { NATS::JetStream::Api::AccountInfoResponse }

      it "makes a request request" do
        call

        expect(client).to have_received(:request).with(
          "$JS.API.INFO.consumer", "{}"
        )
      end

      it "wraps the result with response" do
        expect(call).to be_kind_of(response).and(
          have_attributes(data: have_attributes(streams: 5, consumers: 10))
        )
      end
    end

    context "when response is not defined" do
      let(:response) { false }

      it "makes a publish request" do
        call

        expect(client).to have_received(:publish).with(
          "$JS.API.INFO.consumer", "{}", nil
        )
      end
    end

    context "when subject is present" do
      let(:subject) { "consumer" }

      it "makes a request with the provided subject" do
        call

        expect(client).to have_received(:request).with(
          "$JS.API.INFO.consumer", "{}"
        )
      end
    end

    context "when subject is nil" do
      let(:subject) { nil }

      it "makes a request without a specific subject" do
        call

        expect(client).to have_received(:request).with(
          "$JS.API.INFO", "{}"
        )
      end
    end

    context "when data is present" do
      let(:data) { {stream_name: "stream"} }

      it "sends data with a request" do
        call

        expect(client).to have_received(:request).with(
          "$JS.API.INFO.consumer", "{\"stream_name\":\"stream\"}"
        )
      end
    end

    context "when data is nil" do
      let(:data) { {} }

      it "sends no data with a request" do
        call

        expect(client).to have_received(:request).with(
          "$JS.API.INFO.consumer", "{}"
        )
      end
    end

    context "when params are params" do
      let(:params) { {timeout: 1} }

      context "and response is defined" do
        let(:response) { NATS::JetStream::Api::AccountInfoResponse }

        it "sends params with a request" do
          call

          expect(client).to have_received(:request).with(
            "$JS.API.INFO.consumer", "{}", timeout: 1
          )
        end
      end

      context "and response is not defined" do
        let(:response) { false }

        it "sends params with a publish request" do
          call

          expect(client).to have_received(:publish).with(
            "$JS.API.INFO.consumer", "{}", nil, timeout: 1
          )
        end

        context "with :reply_to option" do
          let(:params) { {reply_to: "inbox", timeout: 1} }

          it "sets reply_to on a publish request" do
            call

            expect(client).to have_received(:publish).with(
              "$JS.API.INFO.consumer", "{}", "inbox", timeout: 1
            )
          end
        end
      end
    end

    context "when params are nil" do
      let(:params) { {} }

      it "sends no params with a request" do
        call

        expect(client).to have_received(:request).with(
          "$JS.API.INFO.consumer", "{}"
        )
      end
    end
  end
end
