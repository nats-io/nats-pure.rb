# frozen_string_literal: true

require_relative "service/extension_examples"

RSpec.describe NATS::Service do
  before(:all) do
    @server = NatsServerControl.new
    @server.start_server(true)
  end

  after(:all) do
    @server.kill_server
  end

  let(:client) { NATS.connect }

  subject { client.add_service(options) }

  let(:service) { subject }

  let(:options) do
    {
      name: "foo",
      version: "1.0.0",
      description: "foo bar",
      queue: "queue"
    }
  end

  after { client.close }

  include_examples "extension"

  describe "#initialize" do
    context "when :name is valid" do
      let(:options) { {name: "foo"} }

      it "sets name" do
        expect(subject.name).to eq("foo")
      end
    end

    context "when :name is invalid" do
      let(:options) { {name: "$foo.*"} }

      it "raises InvalidNameError" do
        expect { subject }.to raise_error(NATS::Service::InvalidNameError)
      end
    end

    context "when :name is blank" do
      let(:options) { {name: nil} }

      it "raises InvalidNameError" do
        expect { subject }.to raise_error(NATS::Service::InvalidNameError)
      end
    end

    context "when :version is valid" do
      let(:options) { {version: "1.0.0-alpha-a.b-c+build.1-aef.1"} }

      it "sets version" do
        expect(subject.version).to eq("1.0.0-alpha-a.b-c+build.1-aef.1")
      end
    end

    context "when :version is invalid" do
      let(:options) { {version: "version-1.0-alpha"} }

      it "raises InvalidVersionError" do
        expect { subject }.to raise_error(NATS::Service::InvalidVersionError)
      end
    end

    context "when :version is blank" do
      let(:options) { {version: nil} }

      it "raises InvalidVersionError" do
        expect { subject }.to raise_error(NATS::Service::InvalidVersionError)
      end
    end

    context "when :description is valid" do
      let(:options) { {description: "bar"} }

      it "sets description" do
        expect(subject.description).to eq("bar")
      end
    end

    context "when :description is blank" do
      let(:options) { {description: nil} }

      it "sets description to nil" do
        expect(subject.description).to be nil
      end
    end

    context "when :metadata is present" do
      let(:options) { {metadata: {foo: :bar}} }

      it "sets metadata" do
        expect(subject.metadata).to eq({foo: :bar})
      end

      it "freezes metadata" do
        expect(subject.metadata.frozen?).to be(true)
      end
    end

    context "when :metadata is blank" do
      let(:options) { {metatada: nil} }

      it "sets metadata to nil" do
        expect(subject.metadata).to be_nil
      end
    end

    context "when :queue is present" do
      let(:options) { {queue: "qux"} }

      it "sets queue" do
        expect(subject.queue).to eq("qux")
      end
    end

    context "when :queue is blank" do
      let(:options) { {queue: nil} }

      it "sets queue to default queue" do
        expect(subject.queue).to eq("q")
      end
    end

    context "when :queue is invalid" do
      let(:options) { {queue: ">qux"} }

      it "raises InvalidQueueError" do
        expect { subject }.to raise_error(NATS::Service::InvalidQueueError)
      end
    end

    xcontext "when an error occurs during setup" do
      before do
        allow(client).to receive(:subscribe).and_raise("Error during subscribe")
        allow(service).to receive(:stop)
      end

      it "stops the service" do
        expect {
          begin
            subject
          rescue
            nil
          end
        }.to receive(:stop)
      end

      it "raises error" do
        expect { subject }.to raise_error("Error during subscribe")
      end
    end
  end

  describe "#on_stats" do
    it "registers :stats callback" do
      subject.on_stats { |endpoint| "stats" }

      expect(subject.callbacks.call(:stats)).to eq("stats")
    end
  end

  describe "#on_stop" do
    it "registers :stop callback" do
      subject.on_stop { |error| "stop" }

      expect(subject.callbacks.call(:stop)).to eq("stop")
    end
  end

  describe "#stopped?" do
    context "service is active" do
      it "returns false" do
        expect(subject.stopped?).to be(false)
      end
    end

    context "service is stopped" do
      it "returns true" do
        service.stop

        expect(subject.stopped?).to be(true)
      end
    end
  end

  describe "#stop" do
    context "when everything goes smoothly" do
      it "stops monitoring" do
        service.stop

        expect(service.monitoring.stopped?).to be(true)
      end

      it "stops endpoints" do
        service.stop

        expect(service.endpoints.map(&:stopped?)).to all be(true)
      end

      it "executs on_stop callback" do
        service.on_stop { puts "Service stopped" }

        expect { service.stop }.to output("Service stopped\n").to_stdout
      end

      it "marks service as stopped" do
        service.stop

        expect(subject.stopped?).to be(true)
      end
    end

    context "when an error occurs during stop" do
      before do
        allow(client).to receive(:drain_sub).and_raise("Error during drain")
      end

      it "marks service as stopped" do
        service.stop

        expect(subject.stopped?).to be(true)
      end

      it "does not raise any error" do
        expect { service.stop }.not_to raise_error
      end
    end

    context "when an error occurs during on_stop" do
      before do
        service.on_stop { raise "Error during on_stop" }
      end

      it "stops monitoring" do
        begin
          service.stop
        rescue
          nil
        end

        expect(service.monitoring.stopped?).to be(true)
      end

      it "stops endpoints" do
        begin
          service.stop
        rescue
          nil
        end

        expect(service.endpoints.map(&:stopped?)).to all be(true)
      end

      it "marks service as stopped" do
        begin
          service.stop
        rescue
          nil
        end

        expect(subject.stopped?).to be(true)
      end

      it "raises error from on_stop" do
        expect { service.stop }.to raise_error("Error during on_stop")
      end
    end
  end

  describe "#reset" do
    before do
      subject.add_endpoint("bar") { |msg| msg.respond("bar") }
      subject.add_endpoint("baz") { |msg| msg.respond("baz") }

      client.request("bar")
      client.request("baz")
    end

    it "resets all endpoints stats" do
      subject.reset
      stats = subject.endpoints.map(&:stats)

      expect(stats).to all have_attributes(
        num_requests: 0,
        processing_time: 0,
        average_processing_time: 0,
        num_errors: 0,
        last_error: ""
      )
    end
  end

  describe "#info" do
    it "returns info" do
      expect(subject.info).to eq({
        name: "foo",
        id: subject.id,
        version: "1.0.0",
        description: "foo bar",
        metadata: nil,
        endpoints: []
      })
    end
  end

  describe "#stats" do
    before do
      Timecop.freeze(Time.parse("2025-01-25 05:45:10.700 -0200"))
    end

    after { Timecop.return }

    it "returns stats" do
      expect(subject.stats).to eq({
        name: "foo",
        id: subject.id,
        version: "1.0.0",
        metadata: nil,
        started: "2025-01-25T07:45:10Z",
        endpoints: []
      })
    end
  end

  describe "#service" do
    it "returns self" do
      expect(subject.service).to eq(subject)
    end
  end
end
