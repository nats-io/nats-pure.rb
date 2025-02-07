# frozen_string_literal: true

RSpec.describe NATS::JetStream::Api::DSL do
  let(:api) { NATS::JetStream::Api.new(jetstream) }
  let(:jetstream) { NATS::JetStream::Context.new(client) }
  let(:client) { double(NATS::Client) }

  let(:parent) { Class.new(NATS::JetStream::Api::Group) }
  let(:group) { parent.new(parent: api, name: :api) }

  describe ".group" do
    let(:define_group) do
      parent.group(:stream) do
        endpoint :info, response: NATS::JetStream::Api::StreamInfoResponse
      end
    end

    it "defines a new sub-group class" do
      define_group

      expect(group.stream).to respond_to(:info)
    end

    it "defines a sub-group method" do
      define_group

      expect(group.stream).to be_a(NATS::JetStream::Api::Group).and(
        have_attributes(name: :stream)
      )
    end
  end

  describe ".endpoint" do
    let(:define_endpoint) do
      parent.endpoint(:info, response: response, request: request, subject: subject)
    end

    let(:response) { NATS::JetStream::Api::StreamInfoResponse }
    let(:request) { NATS::JetStream::Api::StreamInfoRequest }
    let(:subject) { false }

    let(:data) { {config: {name: "stream"}} }
    let(:params) { {timeout: 5} }

    before do
      allow_any_instance_of(NATS::JetStream::Api::Endpoint).to receive(:call)
    end

    context "when request is present" do
      it "defines endpoint reader with the provided request" do
        define_endpoint

        expect(group.info_endpoint).to be_a(NATS::JetStream::Api::Endpoint).and(
          have_attributes(
            name: :info,
            request: request,
            response: response
          )
        )
      end
    end

    context "when request is nil" do
      let(:define_endpoint) { parent.endpoint(:info, response: response, subject: false) }

      it "defines endpoint reader with default request" do
        define_endpoint

        expect(group.info_endpoint).to be_a(NATS::JetStream::Api::Endpoint).and(
          have_attributes(
            name: :info,
            request: NATS::JetStream::Api::Request,
            response: response
          )
        )
      end
    end

    context "when subject is true" do
      let(:subject) { true }

      it "defines endpoint method with subject" do
        define_endpoint

        group.info("stream")
        expect(group.info_endpoint).to have_received(:call).with("stream", {}, {})
      end

      it "defines endpoint method that accepts data" do
        define_endpoint

        group.info("stream", data)
        expect(group.info_endpoint).to have_received(:call).with("stream", data, {})
      end

      it "defines endpoint method that accepts params" do
        define_endpoint

        group.info("stream", data, params)
        expect(group.info_endpoint).to have_received(:call).with("stream", data, params)
      end
    end

    context "when subject is false" do
      it "defines endpoint method without subject" do
        define_endpoint

        group.info
        expect(group.info_endpoint).to have_received(:call).with(nil, {}, {})
      end

      it "defines endpoint method that accepts data" do
        define_endpoint

        group.info(data)
        expect(group.info_endpoint).to have_received(:call).with(nil, data, {})
      end

      it "defines endpoint method that accepts params" do
        define_endpoint

        group.info(data, params)
        expect(group.info_endpoint).to have_received(:call).with(nil, data, params)
      end
    end
  end
end
