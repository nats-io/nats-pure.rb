# frozen_string_literal: true

RSpec.describe NATS::JetStream::Api::Request do
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
  end

  describe "#to_json" do
    let(:data) { {batch: "10", expires: 100, no_wait: "t"} }

    context "when schema is set" do
      subject { NATS::JetStream::Api::ConsumerGetNextRequest.new(data) }

      it "runs data through schema and calls to_json" do
        expect(subject.to_json).to eq(
          "{\"expires\":100,\"batch\":10,\"max_bytes\":null,\"no_wait\":true,\"idle_heartbeat\":null}"
        )
      end
    end

    context "when no schema is set" do
      subject { described_class.new(data) }

      it "calls to_json on data" do
        expect(subject.to_json).to eq("{\"batch\":\"10\",\"expires\":100,\"no_wait\":\"t\"}")
      end
    end
  end
end
