# frozen_string_literal: true

RSpec.describe NATS::JetStream::API::Group do
  subject(:group) do
    described_class.new(parent: parent, name: name)
  end

  let(:name) { :info }

  let(:api) { NATS::JetStream::API.new(jetstream) }
  let(:jetstream) { NATS::JetStream::Context.new(client) }
  let(:client) { double(NATS::Client) }

  describe "#subject" do
    context "when parent is a group" do
      let(:parent) do
        NATS::JetStream::API::Group.new(parent: api, name: :stream)
      end

      it "sets subject using group.subject" do
        expect(group.subject).to eq("$JS.API.STREAM.INFO")
      end
    end

    context "when parent is API" do
      let(:parent) { api }

      it "sets subject using group.subject" do
        expect(group.subject).to eq("$JS.API.INFO")
      end
    end
  end

  describe "#client" do
    let(:parent) { api }

    it "sets client from its parent" do
      expect(group.client).to eq(client)
    end
  end
end
