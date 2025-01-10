# frozen_string_literal: true

describe "JetStream" do
  describe "NATS v2.10 Features" do
    before do
      @tmpdir = Dir.mktmpdir("ruby-jetstream")
      @s = NatsServerControl.new("nats://127.0.0.1:4852", "/tmp/test-nats.pid", "-js -sd=#{@tmpdir}")
      @s.start_server(true)
    end

    after do
      @s.kill_server
      FileUtils.remove_entry(@tmpdir)
    end

    it "should create pull subscribers with multiple filter subjects" do
      skip "requires v2.10" unless ENV["NATS_SERVER_VERSION"] == "main"

      nc = NATS.connect(@s.uri)
      js = nc.jetstream
      js.add_stream(name: "MULTI_FILTER", subjects: ["foo.one.*", "foo.two.*", "foo.three.*"])
      js.add_stream(name: "ANOTHER_MULTI_FILTER", subjects: ["foo.five.*"])

      js.publish("foo.one.1", "1")
      js.publish("foo.two.2", "2")
      js.publish("foo.three.3", "3")
      js.publish("foo.two.2", "22")
      js.publish("foo.one.3", "11")

      # Manually using add_consumer JS API to create an ephemeral.
      expect do
        js.add_consumer("MULTI_FILTER", {
          name: "my-ephemeral",
          filter_subjects: ["foo.one.*", "foo.two.*"]
        })
        # For ephemerals, have to use nil for both subject and durable options
        sub = js.pull_subscribe(nil, nil, name: "my-ephemeral", stream: "MULTI_FILTER")
        msgs = sub.fetch(5)
        msgs.each do |msg|
          msg.ack
        end
        expect(msgs.count).to eql(4)
        expect(msgs[0].subject).to eql("foo.one.1")
        expect(msgs[1].subject).to eql("foo.two.2")
        expect(msgs[2].subject).to eql("foo.two.2")
        expect(msgs[3].subject).to eql("foo.one.3")
      end.to_not raise_error

      # Manually using add_consumer JS API to create a durable.
      expect do
        js.add_consumer("MULTI_FILTER", {
          durable_name: "my-durable",
          filter_subjects: ["foo.three.*"]
        })
        # To bind without creating have to use nil for both subject and durable options.
        sub = js.pull_subscribe(nil, nil, name: "my-durable", stream: "MULTI_FILTER")
        msgs = sub.fetch(5)
        msgs.each do |msg|
          msg.ack
        end
        expect(msgs.count).to eql(1)
        expect(msgs[0].subject).to eql("foo.three.3")
      end.to_not raise_error

      # Binding to stream explicitly.
      expect do
        sub = js.pull_subscribe(["foo.one.1", "foo.two.2"], "MULTI_FILTER_CONSUMER", stream: "MULTI_FILTER")
        info = sub.consumer_info
        expect(info.name).to eql("MULTI_FILTER_CONSUMER")
        expect(info.config.durable_name).to eql("MULTI_FILTER_CONSUMER")
        expect(info.config.max_waiting).to eql(512)
        expect(info.num_pending).to eql(3)

        msgs = sub.fetch(5)
        msgs.each do |msg|
          msg.ack
        end
        expect(msgs.count).to eql(3)
        expect(msgs[0].subject).to eql("foo.one.1")
        expect(msgs[1].subject).to eql("foo.two.2")
        expect(msgs[2].subject).to eql("foo.two.2")
        expect(msgs[2].data).to eql("22")
      end.to_not raise_error

      # Creating a single filter consumer using an Array.
      expect do
        config = NATS::JetStream::API::ConsumerConfig.new(max_waiting: 128)
        sub = js.pull_subscribe(["foo.one.1"], "psub2", config: config)
        info = sub.consumer_info
        expect(info.config.max_waiting).to eql(128)
        expect(info.num_pending).to eql(1)

        msgs = sub.fetch(5)
        msgs.each do |msg|
          msg.ack
        end
        expect(msgs[0].subject).to eql("foo.one.1")
        expect(msgs.count).to eql(1)
      end.to_not raise_error

      # Auto creating a consumer via a loookup.
      expect do
        sub = js.pull_subscribe(["foo.one.1", "foo.two.2"], "psub3")
        info = sub.consumer_info
        expect(info.num_pending).to eql(3)

        msgs = sub.fetch(5)
        msgs.each do |msg|
          msg.ack
        end
        expect(msgs[0].subject).to eql("foo.one.1")
        expect(msgs[1].subject).to eql("foo.two.2")
        expect(msgs[2].subject).to eql("foo.two.2")
        expect(msgs.count).to eql(3)
      end.to_not raise_error

      # Auto creating a consumer with stream that does not match.
      expect do
        sub = js.pull_subscribe(["foo.one.1", "foo.four.4"], "psub4")
        info = sub.consumer_info
        expect(info.num_pending).to eql(3)

        msgs = sub.fetch(5)
        msgs.each do |msg|
          msg.ack
        end
        expect(msgs[0].subject).to eql("foo.one.1")
        expect(msgs[1].subject).to eql("foo.two.2")
        expect(msgs[2].subject).to eql("foo.two.2")
        expect(msgs.count).to eql(3)
      end.to raise_error(NATS::JetStream::Error)

      # Auto creating a consumer with stream that is ambiguous.
      expect do
        sub = js.pull_subscribe(["foo.one.1", "foo.one.2", "foo.five.4"], "psub5")
        info = sub.consumer_info
        expect(info.num_pending).to eql(3)

        msgs = sub.fetch(5)
        msgs.each do |msg|
          msg.ack
        end
        expect(msgs[0].subject).to eql("foo.one.1")
        expect(msgs[1].subject).to eql("foo.two.2")
        expect(msgs[2].subject).to eql("foo.two.2")
        expect(msgs.count).to eql(3)
      end.to raise_error(NATS::JetStream::Error)
    end

    it "should create push subscribers with multiple filter subjects" do
      skip "requires v2.10" unless ENV["NATS_SERVER_VERSION"] == "main"

      nc = NATS.connect(@s.uri)
      js = nc.jetstream
      js.add_stream(name: "MULTI_FILTER", subjects: ["foo.one.*", "foo.two.*", "foo.three.*"])
      js.add_stream(name: "ANOTHER_MULTI_FILTER", subjects: ["foo.five.*"])

      js.publish("foo.one.1", "1")
      js.publish("foo.two.2", "2")
      js.publish("foo.three.3", "3")
      js.publish("foo.two.2", "22")
      js.publish("foo.one.3", "11")

      # Binding to stream explicitly.
      expect do
        sub = js.subscribe(["foo.one.1", "foo.two.2"], durable: "MULTI_FILTER_CONSUMER", stream: "MULTI_FILTER")
        info = sub.consumer_info
        expect(info.name).to eql("MULTI_FILTER_CONSUMER")
        expect(info.config.durable_name).to eql("MULTI_FILTER_CONSUMER")
        expect(info.config.max_waiting).to eql(nil)
        expect(info.num_pending).to eql(3)

        msgs = []
        3.times do
          msg = sub.next_msg
          msg.ack
          msgs << msg
        end
        expect(msgs.count).to eql(3)
        expect(msgs[0].subject).to eql("foo.one.1")
        expect(msgs[1].subject).to eql("foo.two.2")
        expect(msgs[2].subject).to eql("foo.two.2")
        expect(msgs[2].data).to eql("22")
      end.to_not raise_error

      # Creating a single filter consumer using an Array.
      expect do
        sub = js.subscribe(["foo.one.1"], config: {name: "foo"})
        info = sub.consumer_info
        expect(info.name).to eql("foo")
        expect(info.num_pending).to eql(1)
        msg = sub.next_msg
        expect(msg.subject).to eql("foo.one.1")
      end.to_not raise_error

      # Auto creating a consumer via a loookup.
      expect do
        sub = js.subscribe(["foo.one.1", "foo.two.2"], config: {name: "psub3"})
        info = sub.consumer_info
        expect(info.name).to eql("psub3")
        expect(info.num_pending).to eql(3)

        msgs = []
        3.times do
          msg = sub.next_msg
          msg.ack
          msgs << msg
        end
        expect(msgs[0].subject).to eql("foo.one.1")
        expect(msgs[1].subject).to eql("foo.two.2")
        expect(msgs[2].subject).to eql("foo.two.2")
        expect(msgs.count).to eql(3)
      end.to_not raise_error

      # Auto creating a consumer with stream that does not match.
      expect do
        js.subscribe(["foo.one.1", "foo.four.4"])
      end.to raise_error(NATS::JetStream::Error)

      # Auto creating a consumer with stream that is ambiguous.
      expect do
        js.subscribe(["foo.one.1", "foo.one.2", "foo.five.4"])
      end.to raise_error(NATS::JetStream::Error)
    end

    it "should create streams and customers with metadata" do
      skip "requires v2.10" unless ENV["NATS_SERVER_VERSION"] == "main"

      nc = NATS.connect(@s.uri)
      js = nc.jetstream
      stream = js.add_stream({
        name: "WITH_METADATA",
        metadata: {
          foo: "bar",
          hello: "world"
        }
      })
      expect(stream[:config][:metadata][:foo]).to eql("bar")
      expect(stream[:config][:metadata][:hello]).to eql("world")

      stream = js.stream_info("WITH_METADATA")
      expect(stream[:config][:metadata][:foo]).to eql("bar")
      expect(stream[:config][:metadata][:hello]).to eql("world")

      consumer = js.add_consumer("WITH_METADATA", {
        name: "wm",
        metadata: {
          hoge: "fuga",
          quux: "uqbar"
        }
      })
      expect(consumer[:config][:metadata][:hoge]).to eql("fuga")
      expect(consumer[:config][:metadata][:quux]).to eql("uqbar")

      consumer = js.consumer_info("WITH_METADATA", "wm")
      expect(consumer[:config][:metadata][:hoge]).to eql("fuga")
      expect(consumer[:config][:metadata][:quux]).to eql("uqbar")
    end
  end
end
