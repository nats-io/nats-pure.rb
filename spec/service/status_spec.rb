# frozen_string_literal: true

def endpoint(values)
  if values.has_key?(:stats)
    stats = NATS::Service::Stats.new

    values[:stats].each do |key, value|
      stats.instance_variable_set("@#{key}", value)
    end

    values[:stats] = stats
  end

  instance_double(NATS::Service::Endpoint, values)
end

RSpec.describe NATS::Service::Status do
  subject { described_class.new(service) }

  let(:service) do
    instance_double(
      NATS::Service,
      name: "foo",
      id: "bar",
      version: "1.0.0",
      description: "foo bar",
      metadata: {foo: :bar},
      endpoints: endpoints,
      callbacks: NATS::Service::Callbacks.new(nil)
    )
  end

  let(:basic) do
    {
      name: "foo",
      id: "bar",
      version: "1.0.0",
      metadata: {foo: :bar}
    }
  end

  describe "#basic" do
    let(:endpoints) { [] }

    it "returns basic status" do
      expect(subject.basic).to eq(basic)
    end
  end

  describe "#info" do
    context "when service has no endpoints" do
      let(:endpoints) { [] }

      it "returns info status with empty endpoints" do
        expect(subject.info).to eq({
          **basic,
          description: "foo bar",
          endpoints: []
        })
      end
    end

    context "when service has some endpoints" do
      let(:endpoints) do
        [
          endpoint(name: "baz", subject: "foo.baz", queue: "q", metadata: {baz: :qux}),
          endpoint(name: "qux", subject: "foo.qux", queue: "q", metadata: {qux: :baz})
        ]
      end

      it "returns info status with endpoints" do
        expect(subject.info).to eq({
          **basic,
          description: "foo bar",
          endpoints: [
            {name: "baz", subject: "foo.baz", queue_group: "q", metadata: {baz: :qux}},
            {name: "qux", subject: "foo.qux", queue_group: "q", metadata: {qux: :baz}}
          ]
        })
      end
    end
  end

  describe "#stats" do
    before do
      Timecop.freeze(Time.parse("2025-01-25 05:45:10.700 -0200"))
    end

    after { Timecop.return }

    context "when service has no endpoints" do
      let(:endpoints) { [] }

      it "returns stats status with empty endpoints" do
        expect(subject.stats).to eq({
          **basic,
          started: "2025-01-25T07:45:10Z",
          endpoints: []
        })
      end
    end

    context "when service has some endpoints" do
      let(:endpoints) do
        [
          endpoint(
            name: "baz",
            subject: "foo.baz",
            queue: "q",
            stats: {
              num_requests: 1,
              processing_time: 300,
              average_processing_time: 300,
              num_errors: 0,
              last_error: nil
            }
          ),
          endpoint(
            name: "qux",
            subject: "foo.qux",
            queue: "q",
            stats: {
              num_requests: 3,
              processing_time: 1500,
              average_processing_time: 500,
              num_errors: 1,
              last_error: "StandardError"
            }
          )
        ]
      end

      context "when on_stats callback is no registered" do
        it "returns info status with empty data fields" do
          expect(subject.stats).to eq({
            **basic,
            started: "2025-01-25T07:45:10Z",
            endpoints: [
              {
                name: "baz",
                subject: "foo.baz",
                queue_group: "q",
                num_requests: 1,
                processing_time: 300,
                average_processing_time: 300,
                num_errors: 0,
                last_error: nil,
                data: nil
              },
              {
                name: "qux",
                subject: "foo.qux",
                queue_group: "q",
                num_requests: 3,
                processing_time: 1500,
                average_processing_time: 500,
                num_errors: 1,
                last_error: "StandardError",
                data: nil
              }
            ]
          })
        end
      end

      context "when on_stats callback is registered" do
        before do
          service.callbacks.register(:stats) do |endpoint|
            errors = endpoint.stats.num_errors
            requests = endpoint.stats.num_requests

            {errors_rate: (errors.to_f / requests).round(2)}
          end
        end

        it "returns info status with data fields" do
          expect(subject.stats).to eq({
            **basic,
            started: "2025-01-25T07:45:10Z",
            endpoints: [
              {
                name: "baz",
                subject: "foo.baz",
                queue_group: "q",
                num_requests: 1,
                processing_time: 300,
                average_processing_time: 300,
                num_errors: 0,
                last_error: nil,
                data: {errors_rate: 0}
              },
              {
                name: "qux",
                subject: "foo.qux",
                queue_group: "q",
                num_requests: 3,
                processing_time: 1500,
                average_processing_time: 500,
                num_errors: 1,
                last_error: "StandardError",
                data: {errors_rate: 0.33}
              }
            ]
          })
        end
      end
    end
  end
end
