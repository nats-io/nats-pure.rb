# frozen_string_literal: true

RSpec.describe NATS::JetStream::Message do
  subject { described_class.build(consumer, message) }

  let(:consumer) { NATS::JetStream::Consumer.new(stream, name: "consumer") }
  let(:stream) { NATS::JetStream::Stream.new(js, name: "stream") }

  let(:js) { NATS::JetStream::Context.new(client) }
  let(:client) { double(NATS::Client) }

  let(:message) do
    NATS::Msg.new(
      subject: "subject",
      header: header,
      raw_header: "raw_header",
      data: "data",
      reply: "$JS.ACK.stream.consumer.3.2795.3495.1744033099995368000.7"
    )
  end

  describe ".build" do
    context "with Consumer message" do
      let(:header) { {} }

      it "returns Message" do
        expect(subject).to be_a(NATS::JetStream::Message).and(
          have_attributes(
            stream: stream,
            subject: "subject",
            header: {},
            raw_header: "raw_header",
            data: "data",
            reply: "$JS.ACK.stream.consumer.3.2795.3495.1744033099995368000.7"
          )
        )
      end
    end

    context "with Idle Heartbeat" do
      let(:header) { {"Status" => "100"} }

      it "returns IdleHeartbeatMessage" do
        expect(subject).to be_a(NATS::JetStream::IdleHeartbeatMessage).and(
          have_attributes(
            consumer: consumer,
            message: message,
            code: "100",
            description: nil
          )
        )
      end
    end

    context "with Bad Request" do
      let(:header) { {"Status" => "400", "Description" => "Bad Request"} }

      it "returns BadRequestMessage" do
        expect(subject).to be_a(NATS::JetStream::BadRequestMessage).and(
          have_attributes(
            consumer: consumer,
            message: message,
            code: "400",
            description: "Bad Request"
          )
        )
      end
    end

    context "with No Messages" do
      let(:header) { {"Status" => "404", "Description" => "No Messages"} }

      it "returns NoMessagesMessage" do
        expect(subject).to be_a(NATS::JetStream::NoMessagesMessage).and(
          have_attributes(
            consumer: consumer,
            message: message,
            code: "404",
            description: "No Messages"
          )
        )
      end
    end

    context "with Request Timeout" do
      let(:header) { {"Status" => "408", "Description" => "Request Timeout"} }

      it "returns RequestTimeoutMessage" do
        expect(subject).to be_a(NATS::JetStream::RequestTimeoutMessage).and(
          have_attributes(
            consumer: consumer,
            message: message,
            code: "408",
            description: "Request Timeout"
          )
        )
      end
    end

    context "with Exceeded MaxRequestBatch" do
      let(:header) { {"Status" => "409", "Description" => "Exceeded MaxRequestBatch"} }

      it "returns MaxRequestBatchMessage" do
        expect(subject).to be_a(NATS::JetStream::MaxRequestBatchMessage).and(
          have_attributes(
            consumer: consumer,
            message: message,
            code: "409",
            description: "Exceeded MaxRequestBatch"
          )
        )
      end
    end

    context "with Exceeded MaxRequestExpires" do
      let(:header) { {"Status" => "409", "Description" => "Exceeded MaxRequestExpires"} }

      it "returns MaxRequestExpiresMessage" do
        expect(subject).to be_a(NATS::JetStream::MaxRequestExpiresMessage).and(
          have_attributes(
            consumer: consumer,
            message: message,
            code: "409",
            description: "Exceeded MaxRequestExpires"
          )
        )
      end
    end

    context "with Exceeded MaxRequestMaxBytes" do
      let(:header) { {"Status" => "409", "Description" => "Exceeded MaxRequestMaxBytes"} }

      it "returns MaxRequestMaxBytesMessage" do
        expect(subject).to be_a(NATS::JetStream::MaxRequestMaxBytesMessage).and(
          have_attributes(
            consumer: consumer,
            message: message,
            code: "409",
            description: "Exceeded MaxRequestMaxBytes"
          )
        )
      end
    end

    context "with Exceeded MaxWaiting" do
      let(:header) { {"Status" => "409", "Description" => "Exceeded MaxWaiting"} }

      it "returns MaxWaitingMessage" do
        expect(subject).to be_a(NATS::JetStream::MaxWaitingMessage).and(
          have_attributes(
            consumer: consumer,
            message: message,
            code: "409",
            description: "Exceeded MaxWaiting"
          )
        )
      end
    end

    context "with Message Size Exceeds MaxBytes" do
      let(:header) { {"Status" => "409", "Description" => "Message Size Exceeds MaxBytes"} }

      it "returns MaxBytesExceededMessage" do
        expect(subject).to be_a(NATS::JetStream::MaxBytesExceededMessage).and(
          have_attributes(
            consumer: consumer,
            message: message,
            code: "409",
            description: "Message Size Exceeds MaxBytes"
          )
        )
      end
    end

    context "with Batch Completed" do
      let(:header) { {"Status" => "409", "Description" => "Batch Completed"} }

      it "returns BatchCompletedMessage" do
        expect(subject).to be_a(NATS::JetStream::BatchCompletedMessage).and(
          have_attributes(
            consumer: consumer,
            message: message,
            code: "409",
            description: "Batch Completed"
          )
        )
      end
    end

    context "with Consumer Deleted" do
      let(:header) { {"Status" => "409", "Description" => "Consumer Deleted"} }

      it "returns ConsumerDeletedMessage" do
        expect(subject).to be_a(NATS::JetStream::ConsumerDeletedMessage).and(
          have_attributes(
            consumer: consumer,
            message: message,
            code: "409",
            description: "Consumer Deleted"
          )
        )
      end
    end

    context "with Leadership Change" do
      let(:header) { {"Status" => "409", "Description" => "Leadership Change"} }

      it "returns ConsumerLeadershipChangedMessage" do
        expect(subject).to be_a(NATS::JetStream::ConsumerLeadershipChangedMessage).and(
          have_attributes(
            consumer: consumer,
            message: message,
            code: "409",
            description: "Leadership Change"
          )
        )
      end
    end

    context "with no responders message" do
      let(:header) { {"Status" => "503", "Description" => "No Responders"} }

      it "returns NoRespondersMessage" do
        expect(subject).to be_a(NATS::JetStream::NoRespondersMessage).and(
          have_attributes(
            consumer: consumer,
            message: message,
            code: "503",
            description: "No Responders"
          )
        )
      end
    end
  end
end
