# frozen_string_literal: true

describe "Client#close" do
  before(:all) do
    @s = NatsServerControl.new("nats://127.0.0.1:4524", "/tmp/test-nats.pid")
    @s.start_server(true)
  end

  after(:all) do
    @s.kill_server
  end

  # Regression test for #183.
  #
  # The server answers the SUB with -ERR 'Invalid Subject'. The read loop
  # handles it in process_op_error, holding the client lock while
  # initiate_reconnect closes the socket, and the flusher queues on that
  # lock. close then kills both with Thread#exit and waits on the lock
  # itself. When the read loop releases the lock, Ruby's Mutex hands the
  # single wakeup to the first waiter, the flusher, which dies from the
  # kill without passing it on: the lock is free, but close is never
  # woken. This is a lost wakeup in Ruby's Mutex (seen on 3.4 and 4.0),
  # triggered by killing threads that may be waiting on the lock.
  #
  # Timing, not the calling thread, is what matters: the SUB must already
  # be on the wire when close starts, and the -ERR is then handled during
  # close's own Thread.pass, just before the kills. Starting close on a
  # new thread gives up the GVL first, so the flusher sends the SUB in
  # time; calling close straight after subscribe usually would not.
  #
  # Measured on Ruby 3.4.11: 19 in 20 attempts hang, so 20 attempts make
  # a false pass practically impossible. On Ruby 4.0 the window is
  # narrower (2/20 on 4.0.7 Linux, 0/20 on 4.0.6 macOS).
  it "returns while the read loop is handling a server error" do
    20.times do |i|
      nc = NATS.connect(@s.uri)
      nc.subscribe("invalid.")

      closer = Thread.new { nc.close }
      unless closer.join(5)
        raise RSpec::Expectations::ExpectationNotMetError,
          "close did not return within 5s (attempt #{i + 1} of 20)"
      end
      expect(nc.closed?).to be(true)
    end
  end

  # The race above needs Ruby 3.4 to show up reliably. These pin the
  # behaviour that prevents it on every Ruby: background threads are
  # asked to stop and joined, never killed.
  describe "stopping the background threads" do
    let(:killed) { [] }

    before do
      %i[exit kill terminate].each do |m|
        allow_any_instance_of(Thread).to receive(m).and_wrap_original do |original, *args|
          killed << original.receiver.name if original.receiver.name.to_s.start_with?("nats:")
          original.call(*args)
        end
      end
    end

    def background_threads(nc)
      %i[@read_loop_thread @flusher_thread @ping_interval_thread].map { |iv| nc.instance_variable_get(iv) }
    end

    it "joins them on close instead of killing them" do
      nc = NATS.connect(@s.uri)
      threads = background_threads(nc)

      nc.close

      expect(killed).to be_empty
      expect(threads.map(&:alive?)).to eql([false, false, false])
    end

    it "joins the old ones on reconnect instead of killing them" do
      nc = NATS.connect(@s.uri, reconnect_time_wait: 0.1)
      threads = background_threads(nc)

      nc.force_reconnect
      wait_until(description: "the reconnect") { nc.connected? && nc.stats[:reconnects] == 1 }

      expect(killed).to be_empty
      expect(threads.map(&:alive?)).to eql([false, false, false])
      expect(background_threads(nc).map(&:alive?)).to eql([true, true, true])
    ensure
      nc&.close
    end

    it "does not reconnect after close" do
      20.times do |i|
        nc = NATS.connect(@s.uri, reconnect_time_wait: 0.01)
        # The -ERR starts a reconnect; close while it is under way.
        nc.subscribe("invalid.")
        wait_until(description: "the reconnect to start") { nc.reconnecting? || nc.stats[:reconnects] > 0 }
        nc.close

        sleep 0.2 # give a reconnect that ignored the close time to finish
        expect(nc.status).to eql(NATS::IO::CLOSED), "attempt #{i + 1}: client came back after close"
        expect(background_threads(nc).map(&:alive?)).to eql([false, false, false])
      end
    end

    it "completes a close started by the read loop itself" do
      closes = 0
      nc = NATS.connect(@s.uri, reconnect: false)
      nc.on_close { closes += 1 }

      # Without reconnecting, the -ERR makes the read loop call close.
      nc.subscribe("invalid.")

      wait_until(description: "the client to close") { nc.closed? }
      expect(closes).to eql(1)
      expect(killed).to be_empty
    end
  end
end
