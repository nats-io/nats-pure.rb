# frozen_string_literal: true

RSpec.shared_examples "NATS::JetStream::Pull::Config" do
  context "#expires" do
    context "when expires is specified" do
      let(:values) { {expires: 1.to_nsec} }

      it "sets expires to the specified value" do
        expect(subject.expires).to eq(1.to_nsec)
      end
    end

    context "when expires is not specified" do
      it "sets expires to 30 seconds" do
        expect(subject.expires).to eq(30.to_nsec)
      end
    end

    context "when expires < 1 sec" do
      let(:values) { {expires: 100} }

      it "raises MinError" do
        expect { subject }.to raise_error(NATS::Utils::Config::MinError)
      end
    end
  end

  context "#idle_heartbeats" do
    context "when idle_heartbeats is specified" do
      context "and idle_heartbeat <= expires / 2" do
        let(:values) { {expires: 5.to_nsec, idle_heartbeat: 1.to_nsec} }

        it "sets idle_heartbeat to the specified value" do
          expect(subject.idle_heartbeat).to eq(1.to_nsec)
        end
      end

      context "and idle_heartbeat > expires / 2" do
        let(:values) { {expires: 5.to_nsec, idle_heartbeat: 3.to_nsec} }

        it "raises InvalidIdleHeartbeatError" do
          expect { subject }.to raise_error(NATS::JetStream::InvalidIdleHeartbeatError)
        end
      end

      context "and idle_heartbeats < 0.5 sec" do
        let(:values) { {idle_heartbeat: 100} }

        it "raises MinError" do
          expect { subject }.to raise_error(NATS::Utils::Config::MinError)
        end
      end

      context "and idle_heartbeats > 30 sec" do
        let(:values) { {idle_heartbeat: 50.to_nsec} }

        it "raises MaxError" do
          expect { subject }.to raise_error(NATS::Utils::Config::MaxError)
        end
      end
    end

    context "when idle_heartbeats is not specified" do
      let(:values) { {expires: 5.to_nsec} }

      it "sets idle_heartbeats to half of expires" do
        expect(subject.idle_heartbeat).to eq(2.5.to_nsec)
      end
    end
  end

  describe "expires_seconds" do
    let(:values) { {expires: 2.5.to_nsec} }

    it "returns expires in seconds" do
      expect(subject.expires_seconds).to eq(2.5)
    end
  end

  describe "idle_heartbeat_seconds" do
    let(:values) { {idle_heartbeat: 2.5.to_nsec} }

    it "returns idle_heartbeat in seconds" do
      expect(subject.idle_heartbeat_seconds).to eq(2.5)
    end
  end
end
