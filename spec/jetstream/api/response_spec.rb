# frozen_string_literal: true

RSpec.describe NATS::JetStream::Api::Response do
  describe ".schema" do
    context "when schema is defined by a block" do
      subject do
        Class.new(described_class) do
          schema do
            string :stream
            integer :offset
          end
        end
      end

      it "defines a schema with the block" do
        expect(subject.data_schema).to have_attributes(
          superclass: NATS::Utils::Config,
          schema: include(
            stream: be_kind_of(NATS::Utils::Config::StringOption),
            offset: be_kind_of(NATS::Utils::Config::IntegerOption)
          )
        )
      end
    end

    context "when schema is set to a defined config" do
      let(:config) do
        Class.new(NATS::Utils::Config) do
          string :stream
          integer :offset
        end
      end

      subject do
        data_schema = config

        Class.new(described_class) do
          schema data_schema
        end
      end

      it "sets schema to the config" do
        expect(subject.data_schema).to eq(config)
      end
    end

    context "when inherited from another response" do
      let(:superclass) do
        Class.new(described_class) do
          schema do
            string :stream
            integer :offset
          end
        end
      end

      subject { Class.new(superclass) }

      it "inherits the superclass schema" do
        expect(subject.data_schema).to have_attributes(
          superclass: NATS::Utils::Config,
          schema: include(
            stream: be_kind_of(NATS::Utils::Config::StringOption),
            offset: be_kind_of(NATS::Utils::Config::IntegerOption)
          )
        )
      end
    end
  end

  describe ".build" do
    subject do
      Class.new(described_class) do
        schema do
          string :stream
          integer :offset
        end
      end
    end

    let(:message) { NATS::Msg.new(data: data.to_json) }
    let(:build) { subject.build(message) }

    context "when a message is given" do
      let(:data) { {stream: "stream", offset: 5} }

      it "builds a response object" do
        expect(build).to be_kind_of(subject).and(
          have_attributes(data: have_attributes(data))
        )
      end
    end

    context "when an error is given" do
      let(:data) do
        {error: {code: 404, err_code: 10059}}
      end

      it "raises ErrorResponse" do
        expect { build }.to raise_error(::NATS::JetStream::StreamNotFoundError)
      end
    end
  end

  describe "#data" do
    let(:response) do
      Class.new(described_class) do
        schema do
          string :stream
          integer :offset
        end
      end
    end

    subject { response.new(data) }

    let(:data) { {stream: "stream", offset: 5} }

    it "runs data through schema" do
      expect(subject.data).to be_kind_of(response.data_schema)
        .and(have_attributes(data))
    end
  end
end

RSpec.describe NATS::JetStream::Api::ListResponse do
  let(:response) do
    Class.new(described_class) do
      schema do
        integer :total
        integer :offset
        integer :limit
      end
    end
  end

  subject do
    response.new(total: total, offset: offset, limit: limit)
  end

  let(:total) { 10 }
  let(:offset) { 5 }
  let(:limit) { 5 }

  describe "#last?" do
    context "when offset + limit == total" do
      it "returns true" do
        expect(subject.last?).to eq(true)
      end
    end

    context "when offset + limit > total" do
      let(:offset) { 10 }

      it "returns true" do
        expect(subject.last?).to eq(true)
      end
    end

    context "when offset + limit < total" do
      let(:offset) { 0 }

      it "returns false" do
        expect(subject.last?).to eq(false)
      end
    end
  end

  describe "#next_page" do
    it "returns the sum of offset and limit" do
      expect(subject.next_page).to eq(10)
    end
  end
end

RSpec.describe NATS::JetStream::Api::SuccessResponse do
  subject { described_class.new(success: success) }

  describe "#success?" do
    context "when response is successful" do
      let(:success) { true }

      it "returns true" do
        expect(subject.success?).to eq(true)
      end
    end

    context "when response is not successful" do
      let(:success) { false }

      it "returns false" do
        expect(subject.success?).to eq(false)
      end
    end
  end
end

RSpec.describe NATS::JetStream::Api::ErrorResponse do
  subject do
    described_class.new(
      code: code,
      err_code: err_code,
      description: description
    )
  end

  let(:err_code) {}
  let(:description) { "error" }

  context "#to_error" do
    let(:to_error) { subject.to_error }

    context "when server is unavailable" do
      let(:code) { 503 }

      it "returns NATS::JetStream::ServiceUnavailableError" do
        expect(to_error).to be_kind_of(NATS::JetStream::ServiceUnavailableError)
      end

      it "sets error attributes" do
        expect(to_error).to have_attributes(
          code: 503,
          err_code: nil,
          description: "error"
        )
      end
    end

    context "when server error is occured" do
      let(:code) { 500 }

      it "returns NATS::JetStream::ServerError" do
        expect(to_error).to be_kind_of(NATS::JetStream::ServerError)
      end

      it "sets error attributes" do
        expect(to_error).to have_attributes(
          code: 500,
          err_code: nil,
          description: "error"
        )
      end
    end

    context "when stream is not found" do
      let(:code) { 404 }
      let(:err_code) { 10059 }

      it "returns NATS::JetStream::StreamNotFoundError" do
        expect(to_error).to be_kind_of(NATS::JetStream::StreamNotFoundError)
      end

      it "sets error attributes" do
        expect(to_error).to have_attributes(
          code: 404,
          err_code: 10059,
          description: "error"
        )
      end
    end

    context "when consumer is not found" do
      let(:code) { 404 }
      let(:err_code) { 10014 }

      it "returns NATS::JetStream::ConsumerNotFoundError" do
        expect(to_error).to be_kind_of(NATS::JetStream::ConsumerNotFoundError)
      end

      it "sets error attributes" do
        expect(to_error).to have_attributes(
          code: 404,
          err_code: 10014,
          description: "error"
        )
      end
    end

    context "when general 404 is occured" do
      let(:code) { 404 }

      it "returns NATS::JetStream::NotFoundError" do
        expect(to_error).to be_kind_of(NATS::JetStream::NotFoundError)
      end

      it "sets error attributes" do
        expect(to_error).to have_attributes(
          code: 404,
          err_code: nil,
          description: "error"
        )
      end
    end

    context "when bad request is occured" do
      let(:code) { 400 }

      it "returns NATS::JetStream::BadRequestError" do
        expect(to_error).to be_kind_of(NATS::JetStream::BadRequestError)
      end

      it "sets error attributes" do
        expect(to_error).to have_attributes(
          code: 400,
          err_code: nil,
          description: "error"
        )
      end
    end

    context "when any other error is occured" do
      let(:code) { 300 }

      it "returns NATS::JetStream::ApiError" do
        expect(to_error).to be_kind_of(NATS::JetStream::ApiError)
      end

      it "sets error attributes" do
        expect(to_error).to have_attributes(
          code: 300,
          err_code: nil,
          description: "error"
        )
      end
    end
  end
end
