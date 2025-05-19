# frozen_string_literal: true

RSpec.describe NATS::Client::StatusListeners do
  subject { described_class.new }

  let!(:listeners) do
    3.times.map { subject.create }
  end

  after { subject.close }

  describe "#create" do
    it "creates a listener" do
      expect(subject.create).to be_a(SizedQueue)
    end
  end

  describe "#send" do
    let(:send) { subject.send(4) }
    let(:statuses) { listeners.map(&:pop) }

    context "when listeners are active" do
      it "sends status to active listeners " do
        send

        expect(statuses).to all be_a(NATS::Client::StatusListeners::Status).and(
          have_attributes(connecting?: true)
        )
      end
    end

    context "when some listeners are closed" do
      before { listeners.first.close }

      let(:statuses) { listeners.last(2).map(&:pop) }

      it "sends status to active listeners " do
        send

        expect(statuses).to all be_a(NATS::Client::StatusListeners::Status).and(
          have_attributes(connecting?: true)
        )
      end
    end
  end

  describe "#close" do
    it "closes all listeners" do
      subject.close

      expect(listeners.map(&:closed?)).to all be(true)
    end
  end
end

RSpec.describe NATS::Client::StatusListeners::Status do
  subject { described_class.new(status) }

  describe "disconnected?" do
    context "when status is disconnected" do
      let(:status) { 0 }

      it "returns true" do
        expect(subject.disconnected?).to be(true)
      end
    end

    context "when status is not disconnected" do
      let(:status) { 1 }

      it "returns false" do
        expect(subject.disconnected?).to be(false)
      end
    end
  end

  describe "connected?" do
    context "when status is connected" do
      let(:status) { 1 }

      it "returns true" do
        expect(subject.connected?).to be(true)
      end
    end

    context "when status is not connected" do
      let(:status) { 2 }

      it "returns false" do
        expect(subject.connected?).to be(false)
      end
    end
  end

  describe "closed?" do
    context "when status is closed" do
      let(:status) { 2 }

      it "returns true" do
        expect(subject.closed?).to be(true)
      end
    end

    context "when status is not closed" do
      let(:status) { 3 }

      it "returns false" do
        expect(subject.closed?).to be(false)
      end
    end
  end

  describe "reconnecting?" do
    context "when status is reconnecting" do
      let(:status) { 3 }

      it "returns true" do
        expect(subject.reconnecting?).to be(true)
      end
    end

    context "when status is not reconnecting" do
      let(:status) { 4 }

      it "returns false" do
        expect(subject.reconnecting?).to be(false)
      end
    end
  end

  describe "connecting?" do
    context "when status is connecting" do
      let(:status) { 4 }

      it "returns true" do
        expect(subject.connecting?).to be(true)
      end
    end

    context "when status is not connecting" do
      let(:status) { 5 }

      it "returns false" do
        expect(subject.connecting?).to be(false)
      end
    end
  end

  describe "draining_subs?" do
    context "when status is draining_subs" do
      let(:status) { 5 }

      it "returns true" do
        expect(subject.draining_subs?).to be(true)
      end
    end

    context "when status is not draining_subs" do
      let(:status) { 6 }

      it "returns false" do
        expect(subject.draining_subs?).to be(false)
      end
    end
  end

  describe "draining_pubs?" do
    context "when status is draining_pubs" do
      let(:status) { 6 }

      it "returns true" do
        expect(subject.draining_pubs?).to be(true)
      end
    end

    context "when status is not draining_pubs" do
      let(:status) { 0 }

      it "returns false" do
        expect(subject.draining_pubs?).to be(false)
      end
    end
  end
end
