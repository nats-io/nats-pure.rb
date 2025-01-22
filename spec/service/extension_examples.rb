# frozen_string_literal: true

RSpec.shared_examples "extension" do |params|
  let(:subject_value) { "#{subject.subject}.baz" }

  describe "#add_group" do
    context "when queue is specified" do
      let(:add_group) { subject.add_group("baz", queue: "qux") }

      it "creates group" do
        expect(add_group).to be_kind_of(NATS::Service::Group)
          .and have_attributes(name: "baz", subject: subject_value, queue: "qux")
      end

      it "sets group attributes" do
        expect(add_group).to have_attributes(name: "baz", subject: subject_value, queue: "qux")
      end

      it "adds group to service.groups" do
        group = add_group

        expect(service.groups).to include(group)
      end
    end

    context "when queue is not specified" do
      let(:add_group) { subject.add_group("baz") }

      it "creates group" do
        expect(add_group).to be_kind_of(NATS::Service::Group)
      end

      it "sets group attrbiutes" do
        expect(add_group).to have_attributes(name: "baz", subject: subject_value, queue: "queue")
      end

      it "adds group to service.groups" do
        group = add_group

        expect(service.groups).to include(group)
      end
    end
  end

  describe "#add_endpoint" do
    context "when options are specified" do
      let(:add_endpoint) { subject.add_endpoint("baz", queue: "qux") }

      it "creates endpoint" do
        expect(add_endpoint).to be_kind_of(NATS::Service::Endpoint)
      end

      it "sets endpoint attributes" do
        expect(add_endpoint).to have_attributes(name: "baz", subject: subject_value, queue: "qux")
      end

      it "adds endpoint to service.endpoints" do
        endpoint = add_endpoint

        expect(service.endpoints).to include(endpoint)
      end
    end

    context "when options are not specified" do
      let(:add_endpoint) { subject.add_endpoint("baz") }

      it "creates endpoint" do
        expect(add_endpoint).to be_kind_of(NATS::Service::Endpoint)
      end

      it "sets endpoint attributes" do
        expect(add_endpoint).to have_attributes(name: "baz", subject: subject_value, queue: "queue")
      end

      it "adds endpoint to service.endpoints" do
        endpoint = add_endpoint

        expect(service.endpoints).to include(endpoint)
      end
    end
  end
end
