# frozen_string_literal: true

RSpec.describe NATS::Utils::Config::IntegerError do
  subject { described_class.new(type, value) }

  let(:type) { NATS::Utils::Config::IntegerOption.new(:option) }
  let(:value) { :value }

  describe "#message" do
    it "returns IntegerError message" do
      expect(subject.message).to eq(":option must respond to to_i, got value")
    end
  end
end

RSpec.describe NATS::Utils::Config::HashError do
  subject { described_class.new(type, value) }

  let(:type) { NATS::Utils::Config::HashOption.new(:option) }
  let(:value) { :value }

  describe "#message" do
    it "returns HashError message" do
      expect(subject.message).to eq(":option must respond to to_h, got value")
    end
  end
end

RSpec.describe NATS::Utils::Config::ArrayError do
  subject { described_class.new(type, value) }

  let(:type) { NATS::Utils::Config::ArrayOption.new(:option) }
  let(:value) { :value }

  describe "#message" do
    it "returns ArrayError message" do
      expect(subject.message).to eq(":option must respond to map, got value")
    end
  end
end

RSpec.describe NATS::Utils::Config::ObjectError do
  subject { described_class.new(type, value) }

  let(:type) { NATS::Utils::Config::ObjectOption.new(:option) }
  let(:value) { :value }

  describe "#message" do
    it "returns ObjectError message" do
      expect(subject.message).to eq(":option must be a hash or a config, got value")
    end
  end
end

RSpec.describe NATS::Utils::Config::EmptyError do
  subject { described_class.new(type, value) }

  let(:type) { NATS::Utils::Config::StringOption.new(:option) }
  let(:value) { :value }

  describe "#message" do
    it "returns EmptyError message" do
      expect(subject.message).to eq(":option must be filled")
    end
  end
end

RSpec.describe NATS::Utils::Config::InclusionError do
  subject { described_class.new(type, value) }

  let(:type) { NATS::Utils::Config::StringOption.new(:option, in: %w[file memory]) }
  let(:value) { :value }

  describe "#message" do
    it "returns InclusionError message" do
      expect(subject.message).to eq(":option must be in [\"file\", \"memory\"], got value")
    end
  end
end

RSpec.describe NATS::Utils::Config::MaxError do
  subject { described_class.new(type, value) }

  let(:type) { NATS::Utils::Config::IntegerOption.new(:option, max: 5) }
  let(:value) { :value }

  describe "#message" do
    it "returns MaxError message" do
      expect(subject.message).to eq(":option must be less than 5, got value")
    end
  end
end

RSpec.describe NATS::Utils::Config::MinError do
  subject { described_class.new(type, value) }

  let(:type) { NATS::Utils::Config::IntegerOption.new(:option, min: 5) }
  let(:value) { :value }

  describe "#message" do
    it "returns MinError message" do
      expect(subject.message).to eq(":option must be greater than 5, got value")
    end
  end
end
