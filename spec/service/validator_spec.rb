# frozen_string_literal: true

RSpec.describe NATS::Service::Validator do
  describe ".validate" do
    subject { described_class.validate(values) }

    describe ":name" do
      let(:values) { {name: name} }

      context "when name is not present" do
        let(:values) { {} }

        it "does not raise any errors" do
          expect { subject }.not_to raise_error
        end
      end

      context "when name is blank" do
        let(:name) { nil }

        it "raises InvalidNameError" do
          expect { subject }.to raise_error(NATS::Service::InvalidNameError)
        end
      end

      context "when name contains only A-Za-z0-9-_" do
        let(:name) { "valid_name-100" }

        it "raises InvalidNameError" do
          expect { subject }.not_to raise_error
        end
      end

      context "when name contains other characters" do
        let(:name) { "$name.*" }

        it "raises InvalidNameError" do
          expect { subject }.to raise_error(NATS::Service::InvalidNameError)
        end
      end
    end

    describe ":version" do
      let(:values) { {version: version} }

      context "when version is not present" do
        let(:values) { {} }

        it "does not raise any errors" do
          expect { subject }.not_to raise_error
        end
      end

      context "when version is blank" do
        let(:version) { nil }

        it "raises InvalidVersionError" do
          expect { subject }.to raise_error(NATS::Service::InvalidVersionError)
        end
      end

      context "when version is a valid SemVer string" do
        let(:version) { "1.0.0-alpha-a.b-c+build.1-aef.1" }

        it "raises InvalidVersionError" do
          expect { subject }.not_to raise_error
        end
      end

      context "when version is not a valid SemVer string" do
        let(:version) { "version-1.0-alpha" }

        it "raises InvalidVersionError" do
          expect { subject }.to raise_error(NATS::Service::InvalidVersionError)
        end
      end
    end

    describe ":subject" do
      let(:values) { {subject: subject_value} }

      context "when subject is not present" do
        let(:values) { {} }

        it "does not raise any errors" do
          expect { subject }.not_to raise_error
        end
      end

      context "when subject is blank" do
        let(:subject_value) { nil }

        it "does not raise any errors" do
          expect { subject }.not_to raise_error
        end
      end

      context "when subject is valid" do
        let(:subject_value) { "subject.>" }

        it "raises InvalidSubjectError" do
          expect { subject }.not_to raise_error
        end
      end

      context "when subject is invalid" do
        let(:subject_value) { " > subject" }

        it "raises InvalidSubjectError" do
          expect { subject }.to raise_error(NATS::Service::InvalidSubjectError)
        end
      end
    end

    describe ":queue" do
      let(:values) { {queue: queue} }

      context "when queue is not present" do
        let(:values) { {} }

        it "does not raise any errors" do
          expect { subject }.not_to raise_error
        end
      end

      context "when queue is blank" do
        let(:queue) { nil }

        it "does not raise any errors" do
          expect { subject }.not_to raise_error
        end
      end

      context "when queue is valid" do
        let(:queue) { "queue.>" }

        it "raises InvalidQueueError" do
          expect { subject }.not_to raise_error
        end
      end

      context "when queue is invalid" do
        let(:queue) { " > queue" }

        it "raises InvalidQueueError" do
          expect { subject }.to raise_error(NATS::Service::InvalidQueueError)
        end
      end
    end
  end
end
