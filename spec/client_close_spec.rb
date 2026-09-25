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
end
