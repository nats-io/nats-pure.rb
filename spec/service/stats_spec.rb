# frozen_string_literal: true

RSpec.describe NATS::Service::Stats do
  subject { described_class.new }

  it "initializes with initial values" do
    expect(subject).to have_attributes(
      num_requests: 0,
      processing_time: 0,
      average_processing_time: 0,
      num_errors: 0,
      last_error: ""
    )
  end

  describe "#reset" do
    before do
      5.times { subject.record(Time.now) }
      5.times { subject.error(StandardError.new) }
    end

    it "resets to initial values" do
      subject.reset

      expect(subject).to have_attributes(
        num_requests: 0,
        processing_time: 0,
        average_processing_time: 0,
        num_errors: 0,
        last_error: ""
      )
    end
  end

  describe "#record" do
    after { Timecop.return }

    let(:started_at) { Time.parse("2025-01-25 05:45:10.500") }

    context "when there have been no records" do
      before do
        Timecop.freeze(Time.parse("2025-01-25 05:45:10.700"))
      end

      it "increses num_requests" do
        subject.record(started_at)

        expect(subject.num_requests).to eq(1)
      end

      it "calculates processing_time in nanoseconds" do
        subject.record(started_at)

        expect(subject.processing_time).to eq(200_000_000)
      end

      it "calculates average_processing_time in nanoseconds" do
        subject.record(started_at)

        expect(subject.average_processing_time).to eq(200_000_000)
      end
    end

    context "when there have been records" do
      before do
        Timecop.freeze(Time.parse("2025-01-25 05:45:10.300"))
        subject.record(Time.parse("2025-01-25 05:45:10.000"))

        Timecop.freeze(Time.parse("2025-01-25 05:45:10.700"))
      end

      it "increses num_requests" do
        subject.record(started_at)

        expect(subject.num_requests).to eq(2)
      end

      it "calculates processing_time in nanoseconds" do
        subject.record(started_at)

        expect(subject.processing_time).to eq(500_000_000)
      end

      it "calculates average_processing_time in nanoseconds" do
        subject.record(started_at)

        expect(subject.average_processing_time).to eq(250_000_000)
      end
    end
  end

  describe "#error" do
    context "when there have been no errors" do
      it "increases num_errors" do
        subject.error(StandardError.new)

        expect(subject.num_errors).to eq(1)
      end

      it "sets last_error to the error message" do
        subject.error(StandardError.new)

        expect(subject.last_error).to eq("StandardError")
      end
    end

    context "when there errors have already occured" do
      before { subject.error(StandardError.new) }

      it "increases num_errors" do
        subject.error(StandardError.new)

        expect(subject.num_errors).to eq(2)
      end

      it "replaces last_error with the new error message" do
        subject.error(StandardError.new("Error"))

        expect(subject.last_error).to eq("Error")
      end
    end
  end
end
