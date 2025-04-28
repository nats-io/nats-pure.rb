# frozen_string_literal: true

require_relative "../pull/handler_examples"

RSpec.describe NATS::JetStream::Consume::Handler do
  before(:all) do
    @server = NatsServerControl.new
    @server.start_server(true)
  end

  after(:all) do
    @server.kill_server
  end

  subject { described_class.new(pull, &block) }

  let(:pull) { NATS::JetStream::Consume.new(consumer, params) }
  let(:params) { {} }
  let(:block) {}

  let(:consumer) { NATS::JetStream::Consumer.new(stream, name: "consumer") }
  let(:stream) { NATS::JetStream::Stream.new(js, name: "stream") }

  let(:js) { NATS::JetStream::Context.new(client) }
  let(:client) { NATS.connect }

  let(:heartbeats) { pull.heartbeats.send(:task) }
  let(:buffer) { pull.buffer }

  let(:message) do
    NATS::Msg.new(
      subject: "subject",
      header: header,
      data: "data",
      reply: "$JS.ACK.stream.consumer.3.2795.3495.1744033099995368000.7"
    )
  end

  before do
    pull.heartbeats.start

    allow(pull).to receive(:request_messages)
    allow(pull).to receive(:drain)
  end

  after { pull.heartbeats.stop }

  include_examples "NATS::JetStream::Handler"

  describe "#handle" do
    let(:handle) { subject.handle(message) }

    context "with a consumer message" do
      let(:header) { {} }
      let(:block) { ->(message) { message } }

      before do
        allow(block).to receive(:call)
      end

      it "resets heartbeat timer" do
        schedule_time = heartbeats.schedule_time

        handle

        expect(heartbeats.schedule_time).to be > schedule_time
      end

      it "calls block with the message" do
        handle

        expect(block).to have_received(:call)
      end

      it "updates buffer" do
        handle

        expect(buffer.messages_pending).to eq(99)
      end

      context "when buffer is depleting" do
        let(:params) { {max_messages: 2} }

        context "and pull is in process" do
          before { pull.processing! }

          it "requests new messages" do
            handle

            expect(pull).to have_received(:request_messages)
          end

          it "refills buffer" do
            handle

            expect(buffer.messages_pending).to eq(3)
          end
        end

        context "and pull is draining" do
          before { pull.draining! }

          it "does not request new messages" do
            handle

            expect(pull).to_not have_received(:request_messages)
          end

          it "does not refill buffer" do
            handle

            expect(buffer.messages_pending).to eq(1)
          end
        end
      end
    end

    context "with an idle heartbeat message" do
      let(:header) { {"Status" => "100"} }

      it "resets heartbeat timer" do
        schedule_time = heartbeats.schedule_time

        handle

        expect(heartbeats.schedule_time).to be > schedule_time
      end
    end

    context "with a pull termination message" do
      context "when message does not contain Nats-Pending headers" do
        let(:header) { {"Status" => "408", "Description" => "Request Timeout"} }

        it "resets heartbeat timer" do
          schedule_time = heartbeats.schedule_time

          handle

          expect(heartbeats.schedule_time).to be > schedule_time
        end
      end

      context "when message contains Nats-Pending headers" do
        let(:header) do
          {
            "Status" => "409",
            "Description" => "Batch Completed",
            "Nats-Pending-Messages" => 5
          }
        end

        it "resets heartbeat timer" do
          schedule_time = heartbeats.schedule_time

          handle

          expect(heartbeats.schedule_time).to be > schedule_time
        end

        it "trims buffer" do
          handle

          expect(buffer.messages_pending).to eq(95)
        end

        context "and buffer is depleting" do
          let(:params) { {max_messages: 7} }

          context "with pull in process" do
            before { pull.processing! }

            it "requests new messages" do
              handle

              expect(pull).to have_received(:request_messages)
            end

            it "refills buffer" do
              handle

              expect(buffer.messages_pending).to eq(9)
            end
          end

          context "with pull in draining" do
            before { pull.draining! }

            it "does not request new messages" do
              handle

              expect(pull).to_not have_received(:request_messages)
            end

            it "does not refill buffer" do
              handle

              expect(buffer.messages_pending).to eq(2)
            end
          end
        end
      end
    end

    context "with an error message" do
      let(:header) { {"Status" => "400", "Description" => "Bad Request"} }

      it "drains pull and sets error to message description" do
        handle

        expect(pull).to have_received(:drain).with(
          be_a(NATS::JetStream::PullMessageError).and(
            have_attributes(message: be_a(NATS::JetStream::BadRequestMessage))
          )
        )
      end
    end
  end
end
