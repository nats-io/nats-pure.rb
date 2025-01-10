# frozen_string_literal: true

describe "Client - Thread safety" do
  before(:all) do
    @s = NatsServerControl.new
    @s.start_server(true)
  end

  after(:all) do
    @s.kill_server
  end

  it "should be able to send and receive messages from different threads" do
    component = Struct.new(:nats, :msgs).new(NATS::IO::Client.new, [])
    component.nats.connect

    q = Queue.new
    threads = []
    thr_a = Thread.new do
      component.nats.subscribe("hello") do |data, reply, subject|
        component.msgs << {data: data, subject: subject}
      end

      q << "hello subscribed"

      loop do
        if component.msgs.count >= 100
          q << "hello done"
          break
        end
        sleep 0.1
      end
    end

    threads << thr_a

    thr_b = Thread.new do
      component.nats.subscribe("world") do |data, reply, subject|
        component.msgs << {data: data, subject: subject}
      end

      q << "world subscribed"

      loop do
        if component.msgs.count >= 100
          q << "world done"
          break
        end
        sleep 0.1
      end
    end
    threads << thr_b

    q.pop
    q.pop

    thr_c = Thread.new do
      (1..100).step(2) do |n|
        component.nats.publish("hello", n.to_s)
      end
      component.nats.flush
    end
    threads << thr_c

    thr_d = Thread.new do
      (0..99).step(2) do |n|
        component.nats.publish("world", n.to_s)
      end
      component.nats.flush
    end
    threads << thr_d

    q.pop
    q.pop
    expect(component.msgs.count).to eql(100)

    result = component.msgs.select { |msg| msg[:subject] != "hello" && msg[:data].to_i % 2 == 1 }
    expect(result.count).to eql(0)

    result = component.msgs.select { |msg| msg[:subject] != "world" && msg[:data].to_i % 2 == 0 }
    expect(result.count).to eql(0)

    result = component.msgs.select { |msg| msg[:subject] == "hello" && msg[:data].to_i % 2 == 1 }
    expect(result.count).to eql(50)

    result = component.msgs.select { |msg| msg[:subject] == "world" && msg[:data].to_i % 2 == 0 }
    expect(result.count).to eql(50)

    component.nats.close

    threads.each do |t|
      t.kill
    end
  end

  it "should allow async subscriptions to process messages in parallel" do
    nc = NATS.connect(servers: ["nats://0.0.0.0:4222"])

    foo_msgs = []
    nc.subscribe("foo") do |payload|
      foo_msgs << payload
      sleep 1
    end

    bar_msgs = []
    nc.subscribe("bar") do |payload, reply|
      bar_msgs << payload
      nc.publish(reply, "OK!")
    end

    quux_msgs = []
    nc.subscribe("quux") do |payload, reply|
      quux_msgs << payload
    end

    # Receive on message foo first which takes longer to process.
    nc.publish("foo", "hello")

    # Publish many messages to quux which should be able to consume fast.
    1.upto(10).each do |n|
      nc.publish("quux", "test-#{n}")
    end

    # Awaiting for the response happens on the same
    # thread where the request is happening, then
    # the read loop thread is going to signal back.
    response = nil
    expect do
      response = nc.request("bar", "help", timeout: 0.5)
    end.to_not raise_error

    expect(response.data).to eql("OK!")

    # Wait a bit in case all of this happened too fast
    sleep 0.2
    expect(foo_msgs.count).to eql(1)
    expect(bar_msgs.count).to eql(1)
    expect(quux_msgs.count).to eql(10)

    1.upto(10).each do |n|
      expect(quux_msgs[n - 1]).to eql("test-#{n}")
    end
    nc.close
  end

  it "should connect once across threads" do
    nc = NATS.connect(@s.uri)
    nc.subscribe(">") {}
    nc.subscribe("help") do |msg, reply|
      nc.publish(reply, "OK!")
    end

    nc2 = NATS::IO::Client.new
    cids = []
    ts = []
    responses = []
    ts << Thread.new do
      nc2.connect(@s.uri)

      loop do
        begin
          nc2.publish("foo", "bar", "quux")
        rescue
          break
        end
        sleep 0.01
      end
    end

    5.times do
      ts << Thread.new do
        # connect should be idempotent across threads.
        nc.connect(@s.uri)
        si = nc.instance_variable_get("@server_info")
        cids << si[:client_id]
        responses << nc.request("help", "hi")
        nc.flush
      end
    end
    sleep 2

    ts.each do |t|
      t.exit
    end
    nc.close
    nc2.close

    results = cids.uniq
    expect(results.count).to eql(1)

    expect(responses.count).to eql(5)
  end

  # Using pure-nats.rb in a Ractor requires URI 0.11.0 or greater due to URI Ractor support.
  major_version, minor_version, _ = Gem.loaded_specs["uri"].version.to_s.split(".").map(&:to_i) if Gem.loaded_specs["uri"]
  if major_version && major_version >= 0 && minor_version >= 11
    it "should be able to process messages in a Ractor" do
      pending "As of Rails 7.0 known to fail with errors about unshareable objects" if defined? Rails

      nc = NATS.connect(@s.uri)

      messages = []
      nc.subscribe("foo") do |msg|
        messages << msg
      end

      r1 = Ractor.new(@s.uri) do |uri|
        r_nc = NATS.connect(uri)

        r_nc.publish("foo", "bar")
        r_nc.flush
        r_nc.close

        "r1 Finished"
      end
      r1.take # wait for Ractor to finish sending messages
      Thread.pass # allow subscription thread to process messages
      expect(messages.count).to eql(1)

      r2 = Ractor.new(@s.uri) do |uri|
        r_nc = NATS.connect(uri)

        r_messages = []
        r_nc.subscribe("bar") do |payload, reply|
          r_nc.publish(reply, "OK!")
          r_messages << payload
        end

        Ractor.yield "r2 Ready"
        sleep 0.01 while r_messages.empty?
      end
      r2.take # wait for Ractor to finish setup

      response = nil
      expect do
        response = nc.request("bar", "baz", timeout: 0.5)
      end.to_not raise_error

      expect(response.data).to eql("OK!")
    end
  end
end
