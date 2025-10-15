# frozen_string_literal: true

RSpec.describe NATS::Object::Store::Meta do
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

  subject { described_class.new(store) }

  let!(:store) { context.stores.create(bucket: "bucket") }
  let(:context) { NATS.connect.object_store }

  after { store.delete }

  describe "#publish" do
    let(:publish) { subject.publish("name", {name: "name"}) }

    let(:message) do
      # Find the message by iterating through stream messages
      stream_info = store.stream.info
      last_seq = stream_info.state.last_seq

      last_seq.downto([last_seq - 10, 1].max).each do |seq|
        msg = store.stream.messages.find(seq: seq)
        if msg.subject == info_subject
          break msg
        end
      rescue NATS::JetStream::MessageNotFoundError, NATS::JetStream::BadRequestError
        next
      end
    end
    let(:info_subject) { "$O.bucket.M.#{Base64.urlsafe_encode64("name")}" }

    it "publishes info" do
      publish

      expect(message.json).to include({name: "name"})
    end

    it "returns Object::Info" do
      expect(publish).to be_a(NATS::Object::Info)
      expect(publish.name).to eq("name")
    end

    context "when info message exists" do
      before { subject.publish("name", {name: "other"}) }

      let(:messages_count) do
        info = store.stream.info(subjects_filter: info_subject)
        info.state.subjects[info_subject.to_sym]
      end

      it "replaces the message with the same name" do
        publish

        expect(messages_count).to eq(1)
      end
    end
  end

  describe "#find" do
    let(:find) { subject.find("name") }

    context "when chunks exist" do
      before { subject.publish("name", {name: "name"}) }

      it "returns last info message" do
        expect(find).to be_a(NATS::Object::Info).and(
          have_attributes(
            name: "name",
            message: be_a(NATS::JetStream::Stream::Message)
          )
        )
      end
    end

    context "when no chunks exist" do
      it "returns nil" do
        expect(find).to be(nil)
      end
    end
  end

  describe "#purge" do
    let(:purge) { subject.purge("name") }

    before { subject.publish("name", {name: "name"}) }

    it "deletes chunk messages" do
      purge

      expect(subject.find("name")).to be(nil)
    end
  end

  describe "#consume" do
    let(:consume) do
      infos = []

      consume = subject.consume(">") do |info, pull|
        infos << info
        pull.stop if info.last?
      end

      consume.wait(1)
      infos
    end

    before do
      subject.publish("first", {name: "first"})
      subject.publish("last", {name: "last"})
    end

    it "consumes chunk messages" do
      consume

      expect(consume).to match([
        be_a(NATS::Object::Info).and(
          have_attributes(name: "first", message: be_a(NATS::JetStream::Message))
        ),
        be_a(NATS::Object::Info).and(
          have_attributes(name: "last", message: be_a(NATS::JetStream::Message))
        )
      ])
    end
  end
end
