# frozen_string_literal: true

RSpec.describe NATS::Service::Endpoint do
  before(:all) do
    @server = NatsServerControl.new
    @server.start_server(true)
  end

  after(:all) do
    @server.kill_server
  end

  let(:client) { NATS.connect }
  let(:subs) { client.instance_variable_get("@subs") }

  let(:service) { client.add_service(name: "foo", queue: "queue") }

  subject do
    described_class.new(name: name, options: options, parent: parent, &block)
  end

  let(:name) { "bar" }
  let(:options) { {} }
  let(:parent) { service }
  let(:block) { ->(msg) { msg.respond("bar") } }

  after do
    service.stop
    client.close
  end

  describe "#initialize" do
    it "sets service" do
      expect(subject.service).to eq(service)
    end

    context "when name is valid" do
      let(:name) { "bar" }

      it "sets name" do
        expect(subject.name).to eq("bar")
      end
    end

    context "when name is invalid" do
      let(:name) { "$bar.*" }

      it "raises InvalidNameError" do
        expect { subject }.to raise_error(NATS::Service::InvalidNameError)
      end
    end

    context "when parent is a service" do
      it "builds sets subject to name" do
        expect(subject.subject).to eq("bar")
      end
    end

    context "when parent is a group" do
      let(:parent) { service.add_group("baz") }

      it "builds subject based on parent.subject" do
        expect(subject.subject).to eq("baz.bar")
      end
    end

    context "when options[:subject] is present" do
      let(:options) { {subject: "baz"} }

      it "builds subject based on options[:subject]" do
        expect(subject.subject).to eq("baz")
      end
    end

    context "when options[:subject] is blank" do
      let(:options) { {subject: nil} }

      it "builds subject based on endpoint name" do
        expect(subject.subject).to eq("bar")
      end
    end

    context "when options[:subject] is invalid" do
      let(:options) { {subject: ">baz"} }

      it "raises InvalidSubjectError" do
        expect { subject }.to raise_error(NATS::Service::InvalidSubjectError)
      end
    end

    context "when options[:queue] is present" do
      let(:options) { {queue: "qux"} }

      it "sets queue to options[:queue]" do
        expect(subject.queue).to eq("qux")
      end
    end

    context "when options[:queue] is blank" do
      let(:options) { {queue: nil} }

      it "sets queue parent.queue" do
        expect(subject.queue).to eq("queue")
      end
    end

    context "when options[:queue] is invalid" do
      let(:options) { {queue: ">qux"} }

      it "raises InvalidQueueError" do
        expect { subject }.to raise_error(NATS::Service::InvalidQueueError)
      end
    end

    context "when options[:metadata] is present" do
      let(:options) { {metadata: {foo: :bar}} }

      it "sets metadata to options[:metadata]" do
        expect(subject.metadata).to eq({foo: :bar})
      end
    end

    context "when options[:metadata] is blank" do
      let(:options) { {metatada: nil} }

      it "sets metadata to nil" do
        expect(subject.metadata).to be_nil
      end
    end
  end

  describe "#stats" do
    it "returns endpoint stats" do
      expect(subject.stats).to be_kind_of(NATS::Service::Stats)
    end
  end

  describe "handler" do
    let(:request) do
      subject
      begin
        client.request("bar")
      rescue
        nil
      end
    end

    context "when there are no errors" do
      it "executes endpoint" do
        expect(request).to have_attributes(data: "bar")
      end

      it "does not record any errors" do
        request

        expect(subject.stats.num_errors).to eq(0)
      end

      it "records stats" do
        request

        expect(subject.stats.num_requests).to eq(1)
      end
    end

    context "when an error occurs" do
      let(:block) { ->(msg) { raise "Endpoint Error" } }

      it "responds with error" do
        expect(request).to have_attributes(header: {"Nats-Service-Error" => "Endpoint Error", "Nats-Service-Error-Code" => "500"})
      end

      it "records error" do
        request

        expect(subject.stats.num_errors).to eq(1)
        expect(subject.stats.last_error).to eq("500:Endpoint Error")
      end

      it "records stats" do
        request

        expect(subject.stats.num_requests).to eq(1)
      end
    end

    context "when NATS error occurs" do
      let(:block) { ->(msg) { raise NATS::IO::ServerError } }

      it "stops service" do
        request

        expect(service.stopped?).to be(true)
      end

      it "records error" do
        request

        expect(subject.stats.num_errors).to eq(1)
        expect(subject.stats.last_error).to eq("500:NATS::IO::ServerError")
      end

      it "records stats" do
        request

        expect(subject.stats.num_requests).to eq(1)
      end
    end
  end

  describe "#stop" do
    context "when everything goes smoothly" do
      it "drains handler subscription" do
        subject.stop

        expect(subs.values).to include(
          having_attributes(subject: "bar", drained: true)
        )
      end

      it "marks endpoint as stopped" do
        subject.stop

        expect(subject.stopped?).to be(true)
      end
    end

    context "when an error occurs" do
      it "does not raise any errors" do
        expect { subject.stop }.not_to raise_error
      end

      it "marks endpoint as stopped" do
        subject.stop

        expect(subject.stopped?).to be(true)
      end
    end
  end

  describe "#reset" do
    before do
      subject
      3.times { client.request("bar") }
    end

    it "resets endpoint stats" do
      subject.reset

      expect(subject.stats).to have_attributes(
        num_requests: 0,
        processing_time: 0,
        average_processing_time: 0,
        num_errors: 0,
        last_error: ""
      )
    end
  end

  describe "#stopped?" do
    context "when endpoint is active" do
      it "returns false" do
        expect(subject.stopped?).to be(false)
      end
    end

    context "when endpoint is stopped" do
      it "returns true" do
        subject.stop

        expect(subject.stopped?).to be(true)
      end
    end
  end
end
