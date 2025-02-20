# frozen_string_literal: true

RSpec.describe NATS::Service::Request do
  subject { described_class.new(options) }

  let(:options) do
    {
      subject: "foo",
      reply: "bar",
      data: "foo.bar",
      header: {},
      nc: nil,
      sub: nil
    }
  end

  describe "#respond_with_error" do
    let(:respond_with_error) { subject.respond_with_error(error) }

    before do
      allow(subject).to receive(:respond_msg)
    end

    let(:respond) do
      {
        subject: "bar",
        header: {
          "Nats-Service-Error" => "error",
          "Nats-Service-Error-Code" => 500
        },
        reply: "",
        data: ""
      }
    end

    context "when argument is a string" do
      let(:error) { "error" }

      it "responds with service error message" do
        respond_with_error

        expect(subject).to have_received(:respond_msg).with have_attributes(respond)
      end
    end

    context "when argument is a hash" do
      let(:error) { {code: 503, description: "error", data: "data"} }

      let(:respond) do
        {
          subject: "bar",
          header: {
            "Nats-Service-Error" => "error",
            "Nats-Service-Error-Code" => 503
          },
          reply: "",
          data: "data"
        }
      end

      it "responds with service error message" do
        respond_with_error

        expect(subject).to have_received(:respond_msg).with have_attributes(respond)
      end
    end

    context "when argument is an error" do
      let(:error) { StandardError.new("error") }

      it "responds with service error message" do
        respond_with_error

        expect(subject).to have_received(:respond_msg).with have_attributes(respond)
      end
    end

    context "when argument is a random object" do
      let(:error) { [1, 2, 3] }

      let(:respond) do
        {
          subject: "bar",
          header: {
            "Nats-Service-Error" => "[1, 2, 3]",
            "Nats-Service-Error-Code" => 500
          },
          reply: "",
          data: ""
        }
      end

      it "responds with argument " do
        respond_with_error

        expect(subject).to have_received(:respond_msg).with have_attributes(respond)
      end
    end
  end
end
