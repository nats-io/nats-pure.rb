# frozen_string_literal: true

RSpec.describe NATS::Object::Put::Meta do
  subject { described_class.new(meta) }

  describe "#initialize" do
    let(:meta) do
      {
        name: "object",
        description: "description",
        headers: {"Header" => "Value"},
        metadata: {key: "value"},
        options: {max_chunk_size: 256 * 1024},
        data: "data"
      }
    end

    it "sets attributes" do
      expect(subject).to have_attributes(
        name: "object",
        description: "description",
        headers: {"Header" => "Value"},
        metadata: {key: "value"},
        options: have_attributes(max_chunk_size: 256 * 1024),
        data: be_a(StringIO).and(have_attributes(string: "data"))
      )
    end
  end
end
