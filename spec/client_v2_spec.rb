# frozen_string_literal: true

describe "Client - v2.2 features" do
  before(:all) do
    @tmpdir = Dir.mktmpdir("ruby-jetstream")
    @s = NatsServerControl.new("nats://127.0.0.1:4523", "/tmp/test-nats.pid", "-js -sd=#{@tmpdir}")
    @s.start_server(true)
  end

  after(:all) do
    @s.kill_server
    FileUtils.remove_entry(@tmpdir)
  end

  it "should receive a message with headers" do
    mon = Monitor.new
    done = mon.new_cond
    mon.new_cond

    nc = NATS::IO::Client.new
    nc.connect(servers: [@s.uri])

    msgs = []

    # Multiple arity is still backwards compatible with v0.7.0
    sub1 = nc.subscribe("hello") do |data, _, _, header|
      msg = NATS::Msg.new(data: data, header: header)
      msgs << msg

      if msgs.count >= 5
        mon.synchronize do
          done.signal
        end
      end
    end

    # Single arity is now a NATS::Msg type
    msgs2 = []
    nc.subscribe("hello") do |msg|
      msgs2 << msg

      if msgs.count >= 5
        mon.synchronize do
          done.signal
        end
      end
    end
    nc.flush

    1.upto(5) do |n|
      data = "hello world-#{"A" * n}"
      msg = NATS::Msg.new(subject: "hello",
        data: data,
        header: {
          foo: "bar",
          hello: "hello-#{n}"
        })
      nc.publish_msg(msg)
      nc.flush
    end

    mon.synchronize { done.wait(1) }

    expect(msgs.count).to eql(5)

    msgs.each_with_index do |msg, i|
      n = i + 1
      expect(msg.data).to eql("hello world-#{"A" * n}")
      expect(msg.header).to eql({"foo" => "bar", "hello" => "hello-#{n}"})
    end

    msgs2.each_with_index do |msg, i|
      n = i + 1
      expect(msg.data).to eql("hello world-#{"A" * n}")
      expect(msg.header).to eql({"foo" => "bar", "hello" => "hello-#{n}"})
    end
    sub1.unsubscribe

    sub3 = nc.subscribe("quux")

    # message with no headers
    nc.publish("quux", "first")

    # empty payload
    nc.publish("quux", header: {foo: "A"})

    # payload and header
    nc.publish("quux", "third", header: {foo: "B"})
    nc.flush

    msg = sub3.next_msg
    expect(msg.header).to be_nil

    msg = sub3.next_msg
    expect(msg.header["foo"]).to eql("A")

    msg = sub3.next_msg
    expect(msg.header["foo"]).to eql("B")

    nc.close
  end

  it "should make requests with headers" do
    nc = NATS::IO::Client.new
    nc.connect(servers: [@s.uri])

    msgs = []
    seq = 0
    nc.subscribe("hello") do |data, reply, _, header|
      seq += 1
      header["response"] = seq
      msg = NATS::Msg.new(data: data, subject: reply, header: header)
      msgs << msg

      nc.publish_msg(msg)
    end
    nc.flush

    1.upto(5) do |n|
      p
      data = "hello world-#{"A" * n}"
      msg = NATS::Msg.new(subject: "hello",
        data: data,
        header: {
          foo: "bar",
          hello: "hello-#{n}"
        })
      resp = nc.request_msg(msg, timeout: 1)
      expect(resp.data).to eql("hello world-#{"A" * n}")
      expect(resp.header).to eql({"foo" => "bar", "hello" => "hello-#{n}", "response" => n.to_s})
      nc.flush
    end
    expect(msgs.count).to eql(5)

    q2 = Queue.new

    nc.subscribe("quux") do |data, reply, _, header|
      q2.pop
      msg = NATS::Msg.new(data: data, subject: reply, header: header.merge({"reply" => "ok"}))
      nc.publish_msg(msg)
    end

    q2.push(1)
    msg = nc.request("quux", timeout: 2, header: {one: "1"})
    expect(msg.data).to eql("")
    expect(msg.header).to eql({"one" => "1", "reply" => "ok"})

    expect do
      msg.respond_msg("foo")
    end.to raise_error TypeError

    expect do
      nc.request("quux", timeout: 0.1, header: {one: "1"})
    end.to raise_error NATS::Timeout
    q2.push(2)
    nc.close
  end

  it "should raise no responders error by default" do
    nc = NATS.connect(servers: [@s.uri])

    expect do
      resp = nc.request("hi", "timeout", timeout: 1)
      expect(resp).to be_nil
    end.to raise_error(NATS::IO::NoRespondersError)

    expect do
      resp = nc.request("hi", "timeout", timeout: 1, old_style: true)
      expect(resp).to be_nil
    end.to raise_error(NATS::IO::NoRespondersError)

    expect do
      resp = nc.old_request("hi", "timeout", timeout: 1)
      expect(resp).to be_nil
    end.to raise_error(NATS::IO::NoRespondersError)

    resp = nil
    expect do
      msg = NATS::Msg.new(subject: "hi")
      resp = nc.request_msg(msg, timeout: 1)
    end.to raise_error(NATS::IO::NoRespondersError)

    result = nc.instance_variable_get(:@resp_map)
    expect(result.keys.count).to eql(0)

    expect(resp).to be_nil

    nc.close
  end

  it "should not raise no responders error if no responders disabled" do
    nc = NATS::IO::Client.new
    nc.connect(servers: [@s.uri], no_responders: false)

    resp = nil
    expect do
      resp = nc.request("hi", "timeout")
    end.to raise_error(NATS::IO::Timeout)

    expect(resp).to be_nil

    # Timed out requests should be cleaned up.
    50.times do
      nc.request("hi", "timeout", timeout: 0.001)
    rescue
      nil
    end

    msg = NATS::Msg.new(subject: "hi")
    50.times do
      nc.request_msg(msg, timeout: 0.001)
    rescue
      nil
    end

    result = nc.instance_variable_get(:@resp_map)
    expect(result.keys.count).to eql(0)

    resp = nil
    expect do
      msg = NATS::Msg.new(subject: "hi")
      resp = nc.request_msg(msg)
    end.to raise_error(NATS::IO::Timeout)

    expect(resp).to be_nil

    nc.close
  end

  it "should not raise no responders error if no responders disabled" do
    nc = NATS::IO::Client.new
    nc.connect(servers: [@s.uri], no_responders: false)

    resp = nil
    expect do
      resp = nc.request("hi", "timeout")
    end.to raise_error(NATS::IO::Timeout)

    expect(resp).to be_nil

    resp = nil
    expect do
      msg = NATS::Msg.new(subject: "hi")
      resp = nc.request_msg(msg)
    end.to raise_error(NATS::IO::Timeout)

    expect(resp).to be_nil

    nc.close
  end

  it "should handle responses with status and description headers" do
    nc = NATS::IO::Client.new
    nc.connect(servers: [@s.uri], no_responders: true)

    # Create sample Stream and pull based consumer from JetStream
    # from which it will be attempted to fetch messages using no_wait.
    stream_req = {
      name: "foojs",
      subjects: ["foo.js"]
    }

    # Create the stream.
    resp = nc.request("$JS.API.STREAM.CREATE.foojs", stream_req.to_json)
    expect(resp).to_not be_nil

    # Publish with ack.
    resp = nc.request("foo.js", "hello world")
    expect(resp).to_not be_nil
    expect(resp.header).to be_nil

    # Create the consumer.
    consumer_req = {
      stream_name: "foojs",
      config: {
        durable_name: "sample",
        deliver_policy: "all",
        ack_policy: "explicit",
        max_deliver: -1,
        replay_policy: "instant"
      }
    }
    resp = nc.request("$JS.API.CONSUMER.DURABLE.CREATE.foojs.sample", consumer_req.to_json)
    expect(resp).to_not be_nil

    # Get single message.
    pull_req = {no_wait: true, batch: 1}
    resp = nc.request("$JS.API.CONSUMER.MSG.NEXT.foojs.sample", pull_req.to_json, old_style: true)
    expect(resp).to_not be_nil
    expect(resp.data).to eql("hello world")

    # Fail to get next message.
    resp = nc.request("$JS.API.CONSUMER.MSG.NEXT.foojs.sample", pull_req.to_json, old_style: true)
    expect(resp).to_not be_nil
    expect(resp.header).to_not be_nil
    expect(resp.header).to eql({"Status" => "404", "Description" => "No Messages"})

    nc.close
  end

  it "should get a message with Subscription#next_msg" do
    nc = NATS::IO::Client.new
    nc.connect(servers: [@s.uri])

    sub = nc.subscribe("hello")
    msgs = []
    expect do
      sub.next_msg
    end.to raise_error(NATS::IO::Timeout)

    1.upto(5) do |n|
      data = "hello world-#{"A" * n}"
      msg = NATS::Msg.new(subject: "hello",
        data: data,
        header: {
          foo: "bar",
          hello: "hello-#{n}"
        })
      nc.publish_msg(msg)
      nc.flush
    end
    1.upto(5) { msgs << sub.next_msg }

    expect(msgs.first).to have_attributes(
      subject: "hello",
      reply: nil,
      data: a_string_starting_with("hello world"),
      header: {"foo" => "bar", "hello" => "hello-1"}
    )

    msgs.each_with_index do |msg, i|
      n = i + 1
      expect(msg.data).to eql("hello world-#{"A" * n}")
      expect(msg.header).to eql({"foo" => "bar", "hello" => "hello-#{n}"})
    end

    expect do
      sub.next_msg
    end.to raise_error(NATS::IO::Timeout)

    nc.close
  end

  it "should support NATS::Msg#respond" do
    nc = NATS::IO::Client.new
    nc.connect(servers: [@s.uri])
    nc.on_error do |e|
      puts "Error: #{e}"
      puts e.backtrace
    end

    msgs = []
    seq = 0
    nc.subscribe("hello") do |msg|
      seq += 1
      msgs << msg
      msg.respond("hi!")
    end
    nc.flush

    1.upto(5) do |n|
      data = "hello world-#{"A" * n}"
      msg = NATS::Msg.new(subject: "hello",
        data: data,
        header: {
          foo: "bar",
          hello: "hello-#{n}"
        })
      resp = nc.request_msg(msg, timeout: 1)
      expect(resp.data).to eql("hi!")
      nc.flush
    end
    expect(msgs.count).to eql(5)

    nc.close
  end

  it "should make responses with headers NATS::Msg#respond_msg" do
    nc = NATS::IO::Client.new
    nc.connect(servers: [@s.uri])
    nc.on_error do |e|
      puts "Error: #{e}"
      puts e.backtrace
    end

    msgs = []
    seq = 0
    nc.subscribe("hello") do |msg|
      seq += 1
      m = NATS::Msg.new(data: msg.data, subject: msg.reply, header: msg.header)
      m.header["response"] = seq
      msgs << m

      msg.respond_msg(m)
    end
    nc.flush

    1.upto(5) do |n|
      data = "hello world-#{"A" * n}"
      msg = NATS::Msg.new(subject: "hello",
        data: data,
        header: {
          foo: "bar",
          hello: "hello-#{n}"
        })
      resp = nc.request_msg(msg, timeout: 1)
      expect(resp.data).to eql("hello world-#{"A" * n}")
      expect(resp.header).to eql({"foo" => "bar", "hello" => "hello-#{n}", "response" => n.to_s})
      nc.flush
    end
    expect(msgs.count).to eql(5)

    nc.close
  end

  it "should process inline status messages with headers" do
    nc = NATS::IO::Client.new
    tests = [
      {input: %(NATS/1.0\r\nfoo: bar\r\nhello: hello-1\r\n\r\n), expected: {"foo" => "bar", "hello" => "hello-1"}},
      {input: %(NATS/1.0\r\nfoo: bar\r\nhello: hello-1\r\n\r\n), expected: {"foo" => "bar", "hello" => "hello-1"}},
      {input: %(NATS/1.0\r\nfoo: bar\r\nhello: hello-2\r\n\r\n), expected: {"foo" => "bar", "hello" => "hello-2"}},
      {input: %(NATS/1.0\r\nfoo: bar\r\nhello: hello-2\r\n\r\n), expected: {"foo" => "bar", "hello" => "hello-2"}},
      {input: %(NATS/1.0\r\nfoo: bar\r\nhello: hello-3\r\n\r\n), expected: {"foo" => "bar", "hello" => "hello-3"}},
      {input: %(NATS/1.0\r\nfoo: bar\r\nhello: hello-3\r\n\r\n), expected: {"foo" => "bar", "hello" => "hello-3"}},
      {input: %(NATS/1.0\r\nfoo: bar\r\nhello: hello-4\r\n\r\n), expected: {"foo" => "bar", "hello" => "hello-4"}},
      {input: %(NATS/1.0\r\nfoo: bar\r\nhello: hello-4\r\n\r\n), expected: {"foo" => "bar", "hello" => "hello-4"}},
      {input: %(NATS/1.0\r\nfoo: bar\r\nhello: hello-5\r\n\r\n), expected: {"foo" => "bar", "hello" => "hello-5"}},
      {input: %(NATS/1.0\r\nfoo: bar\r\nhello: hello-5\r\n\r\n), expected: {"foo" => "bar", "hello" => "hello-5"}},
      {input: %(NATS/1.0 408 Request Timeout\r\nNats-Pending-Messages: 1\r\nNats-Pending-Bytes: 0\r\n\r\n),
       expected: {"Status" => "408", "Nats-Pending-Messages" => "1", "Nats-Pending-Bytes" => "0", "Description" => "Request Timeout"}},
      {input: %(NATS/1.0 404 No Messages\r\n\r\n),
       expected: {"Status" => "404", "Description" => "No Messages"}}
    ]
    tests.each do |test|
      result = nc.send(:process_hdr, test[:input])
      expect(result).to eql(test[:expected])
    end
  end
end
