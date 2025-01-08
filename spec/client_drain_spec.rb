# frozen_string_literal: true

describe "Client - Drain" do
  before(:all) do
    @s = NatsServerControl.new
    @s.start_server(true)
  end

  after(:all) do
    @s.kill_server
  end

  it "should gracefully drain a connection" do
    nc = NATS.connect(drain_timeout: 5)
    nc2 = NATS.connect

    nc.on_error do |e|
      raise RSpec::Expectations::ExpectationNotMetError.new("Unexpected connection error: #{e}")
    end

    future = Future.new

    nc.on_close do |err|
      future.set_result(:closed)
    end

    wait_subs = Future.new
    wait_pubs = Future.new
    reqs_started = Queue.new
    wait_reqs = Future.new

    Thread.new do
      wait_subs.wait_for(2)
      40.times do |i|
        ("a".."b").each do
          payload = "REQ:#{_1}:#{i}"
          nc2.publish(_1, payload * 128)
          sleep 0.01
        end
      end

      wait_pubs.set_result(:ok)

      ("a".."b").map do |sub|
        Thread.new do
          reqs_started << sub
          payload = "REQ:#{sub}"
          nc2.request(sub, payload)
        end
      end.each(&:join)

      wait_reqs.set_result(:ok)
    end

    # A queue to control the speed of processing messages
    sub_queue = Queue.new
    subs = []
    ("a".."b").each do |subject|
      sub = nc.subscribe(subject) do |msg|
        ft = sub_queue.pop
        msg.respond("OK:#{msg.data}") if msg.reply
        sleep 0.01
      ensure
        ft.set_result(:ok)
      end
      subs << sub
    end
    nc.flush
    wait_subs.set_result(:OK)

    # process a few messages
    f1, f2 = Future.new, Future.new
    sub_queue.push(f1)
    sub_queue.push(f2)

    expect(f1.wait_for(1)).to eql(:ok)
    expect(f2.wait_for(1)).to eql(:ok)

    wait_pubs.wait_for(2)

    reqs_started.pop
    reqs_started.pop

    # Start draining process asynchronously.
    nc.drain

    # Release the queue (we have 38 messages left)
    80.times { sub_queue.push(Future.new) }
    result = future.wait_for(2)
    expect(result).to eql(:closed)
    expect(wait_reqs.wait_for(2)).to eql(:ok)
  end

  it "should report drain timeout error" do
    nc = NATS.connect(drain_timeout: 0.5)
    nc2 = NATS.connect

    future = Future.new

    errors = []
    nc.on_error do |e|
      errors << e
      future.set_result(:error)
    end

    wait_subs = Future.new
    wait_pubs = Future.new

    Thread.new do
      wait_subs.wait_for(2)
      10.times do |i|
        ("a".."b").each do
          payload = "REQ:#{_1}:#{i}"
          nc2.publish(_1, payload * 128)
          sleep 0.01
        end
      end

      wait_pubs.set_result(:ok)
    end
    nc.flush

    # A queue to control the speed of processing messages
    sub_queue = Queue.new
    subs = []
    ("a".."b").each do |subject|
      sub = nc.subscribe(subject) do |msg|
        ft = sub_queue.pop
        sleep 0.01
      ensure
        ft&.set_result(:ok)
      end
      subs << sub
    end
    nc.flush

    wait_subs.set_result(:OK)

    # process a few messages
    f1, f2 = Future.new, Future.new
    sub_queue.push(f1)
    sub_queue.push(f2)

    expect(f1.wait_for(1)).to eql(:ok)
    expect(f2.wait_for(1)).to eql(:ok)

    wait_pubs.wait_for(2)

    nc.drain
    result = future.wait_for(2)
    expect(result).to eql(:error)
    expect(errors.first).to be_a(NATS::IO::DrainTimeoutError)
  end
end
