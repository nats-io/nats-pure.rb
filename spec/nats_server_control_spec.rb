# frozen_string_literal: true

describe NatsServerControl do
  describe "#kill_server with an invalid pid file" do
    subject(:control) { described_class.new("nats://127.0.0.1:4979", pid_file) }

    let(:pid_file) { File.join(Dir.mktmpdir("nats-pidfile"), "test-nats.pid") }
    let(:suffixed_pid_file) { "#{pid_file}.4979" }

    after { FileUtils.remove_entry(File.dirname(pid_file)) }

    it "does not send signals when the pid file is empty" do
      File.write(suffixed_pid_file, "")

      expect(control).not_to receive(:`)

      expect { control.kill_server }.not_to raise_error
      expect(File.exist?(suffixed_pid_file)).to be(false)
    end

    it "does not send signals when the pid file contains garbage" do
      File.write(suffixed_pid_file, "not-a-pid")

      expect(control).not_to receive(:`)

      expect { control.kill_server }.not_to raise_error
      expect(File.exist?(suffixed_pid_file)).to be(false)
    end
  end
end
