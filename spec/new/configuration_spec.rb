# frozen_string_literal: true

RSpec.shared_examples "boolean option" do |name, env, default|
  describe ":#{name}" do
    let(:option) { subject.send(name) }

    context "when hash options are provided" do
      let(:options) { { name => true } }

      it "uses hash options value" do
        expect(option).to be(true)
      end
    end

    if env
      context "when ENV options are provided" do
        let(:options) { {} }

        before { ENV[env] = "true" }
        after { ENV.delete(env) }

        it "uses ENV options value" do
          expect(option).to be(true)
        end
      end

      context "when both hash and ENV options are provided" do
        let(:options) { { name => true } }

        before { ENV[env] = "false" }
        after { ENV.delete(env) }

        it "uses hash options value" do
          expect(option).to be(true)
        end
      end
    end

    context "when neither hash nor ENV options are provided" do
      let(:options) { {} }

      it "sets option to default value" do
        expect(option).to eq(default)
      end
    end

    context "when option value is nil" do
      let(:options) { { name => nil } }

      it "sets option to default value" do
        expect(option).to eq(default)
      end
    end

    (%w[1 true t TRUE T] + [1, true]).each do |value|
      context "when option value equals to #{value}" do
        let(:options) { { name => value } }

        it "sets option to true" do
          expect(option).to be(true)
        end
      end
    end

    context "when option value equals to false" do
      let(:options) { { name => false } }

      it "sets option to false" do
        expect(option).to be(false)
      end
    end

    context "when option value is not boolean" do
      let(:options) { { name => :value } }

      it "sets option to false" do
        expect(option).to be(false)
      end
    end
  end
end

RSpec.shared_examples "integer option" do |name, env, default|
  describe ":#{name}" do
    let(:option) { subject.send(name) }

    context "when hash options are provided" do
      let(:options) { { name => 5 } }

      it "uses hash options value" do
        expect(option).to eq(5)
      end
    end

    if env
      context "when ENV options are provided" do
        let(:options) { {} }

        before { ENV[env] = "5" }
        after { ENV.delete(env) }

        it "uses ENV options value" do
          expect(option).to eq(5)
        end
      end

      context "when both hash and ENV options are provided" do
        let(:options) { { name => 5 } }

        before { ENV[env] = "15" }
        after { ENV.delete(env) }

        it "uses hash options value" do
          expect(option).to be(5)
        end
      end
    end

    context "when neither hash nor ENV options are provided" do
      let(:options) { {} }

      it "sets option to default value" do
        expect(option).to eq(default)
      end
    end

    context "when option value is nil" do
      let(:options) { { name => nil } }

      it "sets option to default value" do
        expect(option).to eq(default)
      end
    end

    context "when option value is integer" do
      let(:options) { { name => 5 } }

      it "sets option to the integer value" do
        expect(option).to eq(5)
      end
    end

    context "when option value responds to #to_i" do
      let(:options) { { name => "5" } }

      it "executes to_i on the value" do
        expect(option).to eq(5)
      end
    end

    context "when option value does not respond to #to_i" do
      let(:options) { { name => {} } }

      it "sets option to default value" do
        expect(option).to eq(default)
      end
    end
  end
end

RSpec.describe NATS::Configuration do
  subject { NATS::Configuration.new(options) }

  include_examples "boolean option", :verbose, "NATS_VERBOSE", false
  include_examples "boolean option", :pedantic, "NATS_PEDANTIC", false
  include_examples "boolean option", :old_style_request, nil, false
  include_examples "boolean option", :ignore_discovered_urls, "NATS_IGNORE_DISCOERED_URLS", false
  include_examples "boolean option", :reconnect, "NATS_RECONNECT", true

  include_examples "integer option", :reconnect_time_wait, "NATS_RECONNECT_TIME_WAIT", 2
  include_examples "integer option", :max_reconnect_attempts, "NATS_MAX_RECONNECT_ATTEMPTS", 10
  include_examples "integer option", :ping_interval, "NATS_PING_INTERVAL", 120
  include_examples "integer option", :max_outstanding_pings, "NATS_MAX_OUTSTANDING_PINGS", 2
  include_examples "integer option", :connect_timeout, nil, 2
  include_examples "integer option", :drain_timeout, nil, 30
  include_examples "integer option", :close_timeout, nil, 30
end
