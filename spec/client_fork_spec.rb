# frozen_string_literal: true

return unless Process.respond_to?(:fork) # Skip if fork is not supported (Windows, JRuby, etc)
return unless Process.respond_to?(:_fork) # Skip if around fork callbacks are not supported (before Ruby 3.1)

describe "Client - Fork detection" do
  before do
    @tmpdir = Dir.mktmpdir("ruby-jetstream-fork")
    @s = NatsServerControl.new("nats://127.0.0.1:4524", "/tmp/test-nats.pid", "-js -sd=#{@tmpdir}")
    @s.start_server(true)

    # Fork detection feature tracks instances of NATS::Client in a weak reference map.
    # However, as one-off client instances are made for every test case, they are not garbage collected in time
    # so stale instances are trying to re-connect after fork.
    # Manually clean up the map before every forking test case.
    instances_map = NATS::Client.const_get(:INSTANCES)
    if instances_map.respond_to?(:delete) # Added in Ruby 3.3
      instances_map.each_key(&instances_map.method(:delete))
    else
      GC.start # hope that GC will clear stale instances from the map
    end
  end

  after do
    @s.kill_server
    FileUtils.remove_entry(@tmpdir)
  end

  let(:options) { {} }
  let!(:nats) { NATS.connect("nats://127.0.0.1:4524", options) }

  it "should be able to publish messages from child process after forking" do
    received = nil
    nats.subscribe("forked-topic") do |msg|
      received = msg.data
    end

    pid = fork do
      nats.publish("forked-topic", "hey from the child process")
      nats.flush
      nats.close
    end
    Process.wait(pid)
    expect($?.exitstatus).to be_zero
    expect(received).to eq("hey from the child process")
    nats.close
  end

  it "should be able to make requests messages from child process after forking" do
    nats.subscribe("service") do |msg|
      msg.respond("pong")
    end

    resp = nats.request("service", "ping")
    expect(resp.data).to eq("pong")
    expect(nats.stats).to eq({in_msgs: 2, out_msgs: 2, in_bytes: 8, out_bytes: 8, reconnects: 0})

    pid = fork do
      expect(nats.stats).to eq({in_msgs: 0, out_msgs: 0, in_bytes: 0, out_bytes: 0, reconnects: 0})
      resp = nats.request("service", "ping")

      expect(resp.data).to eq("pong")
      expect(nats.stats).to eq({in_msgs: 1, out_msgs: 1, in_bytes: 4, out_bytes: 4, reconnects: 0})

      nats.publish("dev.null")
      expect(nats.stats).to eq({in_msgs: 1, out_msgs: 2, in_bytes: 4, out_bytes: 4, reconnects: 0})
      subs = nats.instance_variable_get("@subs")
      expect(subs.count).to eq(1)
      spool = nats.instance_variable_get("@server_pool")
      expect(spool.count).to eql(1)
      nats.close
    end
    Process.wait(pid)
    expect($?.exitstatus).to be_zero
    expect(nats.stats).to eq({in_msgs: 3, out_msgs: 3, in_bytes: 12, out_bytes: 12, reconnects: 0})
    subs = nats.instance_variable_get("@subs")
    expect(subs.count).to eq(2)
    spool = nats.instance_variable_get("@server_pool")
    expect(spool.count).to eql(1)
    nats.close
  end

  it "should be able to receive messages from parent process after forking" do
    from_child, to_parent = IO.pipe
    from_parent, to_child = IO.pipe

    pid = fork do # child process
      to_child.close
      from_child.close # close unused ends

      received = false
      nats.subscribe("forked-topic") do |msg|
        to_parent.write(msg.data)
        received = true
      end

      nats.flush

      to_parent.puts("proceed")
      from_parent.gets # Wait for parent to publish message

      timeout = 1.0
      loop {
        break if received || timeout < 0
        Thread.pass # give a chance for subscription thread to catch and handle message
        timeout -= 0.1
        sleep 0.1
      }

      to_parent.write("timed out to receieve message") unless received
    ensure
      to_parent.close
      from_parent.close
      nats.close
    end

    # parent process
    to_parent.close
    from_parent.close # close unused ends

    from_child.gets
    nats.publish("forked-topic", "hey from the parent process")
    nats.flush

    to_child.puts("proceed")

    result = from_child.read
    expect(result).to eq("hey from the parent process")

    to_child.close
    from_child.close
    Process.wait(pid)
  end

  it "should be able to use jetstreams from child process after forking" do
    js = nats.jetstream
    js.add_stream(name: "forked-stream", subjects: ["foo"])

    from_child, to_parent = IO.pipe

    pid = fork do # child process
      from_child.close # close unused ends

      psub = js.pull_subscribe("foo", "bar")
      msgs = psub.fetch(1)
      msgs.each(&:ack)

      to_parent.write(msgs.first.data)
      nats.close
    end
    to_parent.close

    js.publish("foo", "Hey JetStream!")

    result = from_child.read
    expect(result).to eq("Hey JetStream!")

    from_child.close
    Process.wait(pid)
  end

  context "when reconnection is disabled" do
    let(:options) { {reconnect: false} }

    it "raises an error in child process after fork is detected" do
      callback_error = nil
      nats.on_error do |e|
        callback_error = e
      end
      pid = fork do
        expect(nats.closed?).to eql(true)
        expect(callback_error).to be(NATS::IO::ForkDetectedError)
        expect { nats.publish("topic", "whatever") }.to raise_error(NATS::IO::ConnectionClosedError)
      end
      expect(callback_error).to be_nil
      expect(nats.closed?).to eql(false)
      nats.close
      Process.wait(pid)
      expect($?.exitstatus).to be_zero # Make test fail if any expectations in forked process wasn't met
    end
  end
end
