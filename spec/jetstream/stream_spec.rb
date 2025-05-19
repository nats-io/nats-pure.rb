# frozen_string_literal: true

RSpec.describe NATS::JetStream::Stream do
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

  subject! { js.streams.create(name: "stream") }

  let(:js) { NATS.connect.js }

  after {
    begin
      subject.delete
    rescue
      nil
    end
  }

  describe "#config" do
    it "returns config" do
      expect(subject.config).to be_a(NATS::JetStream::Stream::Config)
    end
  end

  describe "#info" do
    let(:info) { subject.info(params) }

    it "returns info" do
      expect(subject.info).to be_a(NATS::JetStream::Stream::Info)
    end

    context "with :deleted_details" do
      let(:params) { {deleted_details: true} }

      it "returns info" do
        expect(subject.info).to be_a(NATS::JetStream::Stream::Info)
      end
    end

    context "with :subjects_filter" do
      let(:params) { {subject_filter: "stream"} }

      it "returns info" do
        expect(subject.info).to be_a(NATS::JetStream::Stream::Info)
      end
    end

    context "with :offset" do
      let(:params) { {offset: 1} }

      it "returns info" do
        expect(subject.info).to be_a(NATS::JetStream::Stream::Info)
      end
    end
  end

  describe "#subject" do
    it "returns stream.config.name" do
      expect(subject.subject).to eq("stream")
    end
  end

  describe "#consumers" do
    it "returns Consumer::List" do
      expect(subject.consumers).to be_a(NATS::JetStream::Consumer::List)
    end
  end

  describe "#messages" do
    it "returns Stream::Messsage::List" do
      expect(subject.messages).to be_a(NATS::JetStream::Stream::Message::List)
    end
  end

  describe "#update" do
    let(:update) { subject.update(discard: "new") }

    it "updates stream" do
      update

      expect(subject.config.discard).to eq("new")
    end
  end

  describe "#delete" do
    context "when stream still exists" do
      it "deletes stream" do
        subject.delete

        expect { js.streams.find("stream") }.to raise_error(NATS::JetStream::StreamNotFoundError)
      end

      it "returns true" do
        expect(subject.delete).to be(true)
      end
    end

    context "when stream has been deleted" do
      before { subject.delete }

      it "raise StreamNotFoundError" do
        expect { subject.delete }.to raise_error(NATS::JetStream::StreamNotFoundError)
      end
    end
  end

  describe "#purge" do
    let(:purge) { subject.purge(params) }

    before do
      3.times { js.publish("stream", "data") }
    end

    context "without params" do
      let(:params) { {} }

      it "purges all messages" do
        purge

        expect(subject.info.state.messages).to eq(0)
      end
    end

    context "with :filter" do
      let(:params) { {filter: "stream"} }

      it "purges messages with subject :filter" do
        purge

        expect(subject.info.state.messages).to eq(0)
      end
    end

    context "with :seq" do
      let(:params) { {seq: 2} }

      it "purges messages up to seq = :seq" do
        purge

        expect(subject.info.state.messages).to eq(2)
        expect(subject.info.state.first_seq).to eq(2)
      end
    end

    context "with :keep" do
      let(:params) { {keep: 1} }

      it "purges messages exceept last :keep messages" do
        purge

        expect(subject.info.state.messages).to eq(1)
        expect(subject.info.state.first_seq).to eq(3)
      end
    end
  end
end
