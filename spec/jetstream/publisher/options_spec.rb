# frozen_string_literal: true

RSpec.describe NATS::JetStream::Publisher::Options do
  subject { described_class.new(options) }

  describe "#initialize" do
    let(:options) do
      {
        message_id: "9f01",
        stream: "stream",
        last_message_id: "8c34",
        last_seq: "5",
        last_subject_seq: "7",
        rollup: "stream",
        timeout: 1
      }
    end

    it "sets options" do
      expect(subject).to be_config(options)
    end
  end

  describe "#header" do
    context "without options" do
      let(:options) { {} }

      it "returns an empty hash" do
        expect(subject.header).to eq({})
      end
    end

    context "with :stream" do
      let(:options) { {stream: "stream"} }

      it "includes Nats-Expected-Stream" do
        expect(subject.header).to eq({"Nats-Expected-Stream" => "stream"})
      end
    end

    context "with :message_id" do
      let(:options) { {message_id: "9f01"} }

      it "includes Nats-Msg-Id" do
        expect(subject.header).to eq({"Nats-Msg-Id" => "9f01"})
      end
    end

    context "with :last_message_id" do
      let(:options) { {last_message_id: "8c34"} }

      it "includes Nats-Expected-Last-Msg-Id" do
        expect(subject.header).to eq({"Nats-Expected-Last-Msg-Id" => "8c34"})
      end
    end

    context "with :last_seq" do
      let(:options) { {last_seq: "5"} }

      it "includes Nats-Expected-Last-Sequence" do
        expect(subject.header).to eq({"Nats-Expected-Last-Sequence" => "5"})
      end
    end

    context "with :last_subject_seq" do
      let(:options) { {last_subject_seq: "7"} }

      it "includes Nats-Expected-Last-Subject-Sequence" do
        expect(subject.header).to eq({"Nats-Expected-Last-Subject-Sequence" => "7"})
      end
    end

    context "with :rollup" do
      let(:options) { {rollup: "stream"} }

      it "includes Nats-Rollup" do
        expect(subject.header).to eq({"Nats-Rollup" => "stream"})
      end
    end
  end
end
