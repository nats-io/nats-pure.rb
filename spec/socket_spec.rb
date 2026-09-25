# frozen_string_literal: true

describe NATS::IO::Socket do
  describe "#connect when the connection is refused" do
    subject(:socket) do
      described_class.new(uri: URI.parse("nats://127.0.0.1:65431"), connect_timeout: 1)
    end

    before do
      allow_any_instance_of(::Socket)
        .to receive(:connect_nonblock)
        .and_raise(IOError, "Connection refused")
    end

    if RUBY_ENGINE == "jruby"
      it "normalizes JRuby's plain IOError to Errno::ECONNREFUSED" do
        expect { socket.connect }.to raise_error(Errno::ECONNREFUSED)
      end
    else
      it "does not reclassify an IOError that mentions a refused connection" do
        expect { socket.connect }.to raise_error(IOError) do |error|
          expect(error).not_to be_a(SystemCallError)
        end
      end
    end
  end
end
