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
        msgs = sub.fetch(4)
        # Nothing else may match the filter.
        expect(sub.consumer_info.num_pending).to eql(0)
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
        msgs = sub.fetch(1)
        # Nothing else may match the filter.
        expect(sub.consumer_info.num_pending).to eql(0)
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

        msgs = sub.fetch(3)
        # Nothing else may match the filter.
        expect(sub.consumer_info.num_pending).to eql(0)
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

        msgs = sub.fetch(1)
        # Nothing else may match the filter.
        expect(sub.consumer_info.num_pending).to eql(0)
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

        msgs = sub.fetch(3)
        # Nothing else may match the filter.
        expect(sub.consumer_info.num_pending).to eql(0)
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

        msgs = sub.fetch(3)
        # Nothing else may match the filter.
        expect(sub.consumer_info.num_pending).to eql(0)
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

        msgs = sub.fetch(3)
        # Nothing else may match the filter.
        expect(sub.consumer_info.num_pending).to eql(0)
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
        expect(info.num_pending + info.num_ack_pending).to eql(3)

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
        # The message may have been delivered already (push consumer).
        expect(info.num_pending + info.num_ack_pending).to eql(1)
        msg = sub.next_msg
        expect(msg.subject).to eql("foo.one.1")
      end.to_not raise_error

      # Auto creating a consumer via a loookup.
      expect do
        sub = js.subscribe(["foo.one.1", "foo.two.2"], config: {name: "psub3"})
        info = sub.consumer_info
        expect(info.name).to eql("psub3")

        # Messages could have been delivered already.
        result = info.num_ack_pending + info.num_redelivered + info.num_pending
        expect(result).to eql(3)

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

      # Create pull subscriber as well in stream with push subscribers
      expect do
        sub = js.pull_subscribe(["foo.one.1", "foo.two.2"], "psub4", {config: {ack_wait: 1}})
        info = sub.consumer_info
        expect(info.name).to eql("psub4")
        result = info.num_ack_pending + info.num_redelivered + info.num_pending
        expect(result).to eql(3)
        # drop the messages so that they are in ack pending
        if info.num_pending > 0
          begin
            sub.fetch(3)
          rescue
          end
        end
        info = sub.consumer_info
        expect(info.num_ack_pending).to eql(3)
        msgs = []
        3.times do
          fetched = sub.fetch(1)
          fetched.each do |msg|
            msg.ack
            msgs << msg
          end
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

    describe "stream configuration" do
      let(:nc) { NATS.connect(@s.uri) }
      let(:js) { nc.jetstream }

      after { nc.close }

      # The stream config as the server reports it, read without the
      # client's decoding, so that a field the client does not send is
      # caught even when the client does not decode it either.
      def raw_stream_config(stream)
        resp = nc.request("$JS.API.STREAM.INFO.#{stream}", "")
        JSON.parse(resp.data, symbolize_names: true)[:config]
      end

      it "creates streams with S2 compression" do
        js.add_stream(name: "S2", subjects: ["s2"], compression: "s2")

        expect(raw_stream_config("S2")[:compression]).to eql("s2")
        expect(js.stream_info("S2").config.compression).to eql("s2")
      end

      it "reports streams created without compression as uncompressed" do
        js.add_stream(name: "PLAIN", subjects: ["plain"])

        expect(js.stream_info("PLAIN").config.compression).to eql("none")
      end

      it "starts streams at the configured first sequence" do
        js.add_stream(name: "FIRST", subjects: ["first"], first_seq: 1000)

        expect(js.publish("first", "a").seq).to eql(1000)
        info = js.stream_info("FIRST")
        expect(info.state.first_seq).to eql(1000)
        expect(info.config.first_seq).to eql(1000)
      end

      it "stores messages under the subject transform destination" do
        js.add_stream(name: "TRANSFORM", subjects: ["orig.>"],
          subject_transform: {src: "orig.>", dest: "dest.>"})

        js.publish("orig.a", "a")

        expect(js.get_msg("TRANSFORM", seq: 1).subject).to eql("dest.a")
        expect(js.stream_info("TRANSFORM").config.subject_transform)
          .to eql({src: "orig.>", dest: "dest.>"})
        # Only streams that mirror or source others report on it.
        expect(js.stream_info("TRANSFORM").mirror).to be_nil
        expect(js.stream_info("TRANSFORM").sources).to be_nil
      end

      it "applies the stream consumer limits to its consumers" do
        js.add_stream(name: "LIMITS", subjects: ["limits"],
          consumer_limits: {max_ack_pending: 100, inactive_threshold: 30 * ::NATS::NANOSECONDS})

        expect(js.stream_info("LIMITS").config.consumer_limits)
          .to eql({inactive_threshold: 30_000_000_000, max_ack_pending: 100})

        # A consumer that sets no limit of its own inherits the stream's.
        expect(js.add_consumer("LIMITS", durable_name: "inherits").config.max_ack_pending).to eql(100)

        # One that asks for more than the stream allows is refused.
        expect do
          js.add_consumer("LIMITS", durable_name: "greedy", max_ack_pending: 200)
        end.to raise_error(NATS::JetStream::Error::APIError) { |e| expect(e.err_code).to eql(10121) }
      end

      it "keeps the 2.10 settings when a fetched config is sent back as an update" do
        js.add_stream(name: "RMW", subjects: ["rmw.>"],
          compression: "s2",
          first_seq: 50,
          subject_transform: {src: "rmw.>", dest: "moved.>"},
          consumer_limits: {max_ack_pending: 100})

        config = js.stream_info("RMW").config
        config.max_msgs = 10
        js.update_stream(config)

        raw = raw_stream_config("RMW")
        expect(raw[:max_msgs]).to eql(10)
        expect(raw[:compression]).to eql("s2")
        expect(raw[:first_seq]).to eql(50)
        expect(raw[:subject_transform]).to eql({src: "rmw.>", dest: "moved.>"})
        expect(raw[:consumer_limits]).to eql({max_ack_pending: 100})
      end

      it "sources messages through the source subject transforms" do
        js.add_stream(name: "ORIGIN", subjects: ["o.>"])
        js.add_stream(name: "OTHER", subjects: ["p.>"])
        js.add_stream(name: "AGG", sources: [
          {name: "ORIGIN", subject_transforms: [{src: "o.>", dest: "agg.o.>"}]},
          {name: "OTHER", subject_transforms: [{src: "p.>", dest: "agg.p.>"}]}
        ])

        js.publish("o.1", "a")

        eventually { expect(js.stream_info("AGG").state.messages).to eql(1) }
        expect(js.get_msg("AGG", seq: 1).subject).to eql("agg.o.1")
        sources = js.stream_info("AGG").sources.sort_by { |source| source[:name] }
        expect(sources.map { |source| [source[:name], source[:subject_transforms]] }).to eql([
          ["ORIGIN", [{src: "o.>", dest: "agg.o.>"}]],
          ["OTHER", [{src: "p.>", dest: "agg.p.>"}]]
        ])
      end

      it "mirrors messages through the mirror subject transforms" do
        js.add_stream(name: "ORIGIN", subjects: ["o.>"])
        js.add_stream(name: "MIRROR",
          mirror: {name: "ORIGIN", subject_transforms: [{src: "o.>", dest: "m.>"}]})

        js.publish("o.1", "a")

        eventually { expect(js.stream_info("MIRROR").state.messages).to eql(1) }
        expect(js.get_msg("MIRROR", seq: 1).subject).to eql("m.1")
        mirror = js.stream_info("MIRROR").mirror
        expect(mirror[:name]).to eql("ORIGIN")
        expect(mirror[:subject_transforms]).to eql([{src: "o.>", dest: "m.>"}])
      end

      it "timestamps stream and consumer info" do
        js.add_stream(name: "TS", subjects: ["ts"])
        created = js.add_consumer("TS", durable_name: "c")

        [js.stream_info("TS").ts, js.consumer_info("TS", "c").ts, created.ts].each do |ts|
          expect(ts).to be_a(Time)
          expect((Time.now - ts).abs).to be < 60
        end

        # Each report carries the time it was made, not a fixed time such
        # as when the stream or consumer was created.
        first = js.stream_info("TS").ts
        expect(js.stream_info("TS").ts).to be > first
        first = js.consumer_info("TS", "c").ts
        expect(js.consumer_info("TS", "c").ts).to be > first
      end
    end

    describe "consumer create and update actions" do
      let(:nc) { NATS.connect(@s.uri) }
      let(:js) { nc.jetstream }

      before { js.add_stream(name: "ACTIONS", subjects: ["actions"]) }
      after { nc.close }

      it "creates a consumer that does not exist" do
        expect(js.create_consumer("ACTIONS", durable_name: "c", max_ack_pending: 10).name).to eql("c")

        expect(js.consumer_info("ACTIONS", "c").config.max_ack_pending).to eql(10)
      end

      it "creates an ephemeral consumer when given no name" do
        name = js.create_consumer("ACTIONS", ack_policy: "explicit").name

        expect(js.consumer_info("ACTIONS", name).config.durable_name).to be_nil
      end

      it "accepts creating a consumer again with the same config" do
        js.create_consumer("ACTIONS", durable_name: "c", max_ack_pending: 10)

        expect(js.create_consumer("ACTIONS", durable_name: "c", max_ack_pending: 10).name).to eql("c")
      end

      it "refuses to create a consumer that exists with a different config" do
        js.create_consumer("ACTIONS", durable_name: "c", max_ack_pending: 10)

        expect do
          js.create_consumer("ACTIONS", durable_name: "c", max_ack_pending: 20)
        end.to raise_error(NATS::JetStream::Error::ConsumerAlreadyExists) { |e|
          expect(e).to be_a(NATS::JetStream::Error::BadRequest)
          expect(e.err_code).to eql(10148)
        }
        expect(js.consumer_info("ACTIONS", "c").config.max_ack_pending).to eql(10)
      end

      it "updates a consumer that exists" do
        js.create_consumer("ACTIONS", durable_name: "c", max_ack_pending: 10)

        expect(js.update_consumer("ACTIONS", durable_name: "c", max_ack_pending: 20).config.max_ack_pending).to eql(20)
        expect(js.consumer_info("ACTIONS", "c").config.max_ack_pending).to eql(20)
      end

      it "refuses to update a consumer that does not exist" do
        expect do
          js.update_consumer("ACTIONS", durable_name: "missing", max_ack_pending: 20)
        end.to raise_error(NATS::JetStream::Error::ConsumerDoesNotExist) { |e|
          expect(e).to be_a(NATS::JetStream::Error::BadRequest)
          expect(e.err_code).to eql(10149)
        }
        expect { js.consumer_info("ACTIONS", "missing") }.to raise_error(NATS::JetStream::Error::NotFound)
      end

      it "refuses an update the server does not allow" do
        js.create_consumer("ACTIONS", durable_name: "c", ack_policy: "explicit")

        expect do
          js.update_consumer("ACTIONS", durable_name: "c", ack_policy: "all")
        end.to raise_error(NATS::JetStream::Error::APIError) { |e| expect(e.err_code).to eql(10012) }
      end

      it "requires a consumer name to update" do
        expect { js.update_consumer("ACTIONS", max_ack_pending: 20) }.to raise_error(ArgumentError)
        expect { js.update_consumer("ACTIONS", durable_name: "", max_ack_pending: 20) }.to raise_error(ArgumentError)
      end

      it "updates a consumer named by name alone" do
        js.create_consumer("ACTIONS", name: "n", inactive_threshold: 60, max_ack_pending: 10)

        expect(js.update_consumer("ACTIONS", name: "n", inactive_threshold: 60, max_ack_pending: 20)
          .config.max_ack_pending).to eql(20)
      end

      it "updates a consumer from its fetched config" do
        js.create_consumer("ACTIONS", durable_name: "c", filter_subject: "actions", max_deliver: 5, max_ack_pending: 10)

        config = js.consumer_info("ACTIONS", "c").config
        config.max_ack_pending = 20
        info = js.update_consumer("ACTIONS", config)

        expect(info.config.max_ack_pending).to eql(20)
        expect(info.config.filter_subject).to eql("actions")
        expect(info.config.max_deliver).to eql(5)
      end

      it "refuses to create a consumer that exists with a different filter" do
        js.add_stream(name: "FILTERED", subjects: ["filtered.>"])
        js.create_consumer("FILTERED", durable_name: "c", filter_subject: "filtered.a")

        expect do
          js.create_consumer("FILTERED", durable_name: "c", filter_subject: "filtered.b")
        end.to raise_error(NATS::JetStream::Error::ConsumerAlreadyExists)
        expect(js.consumer_info("FILTERED", "c").config.filter_subject).to eql("filtered.a")
      end

      it "reports a missing stream as such when creating or updating" do
        expect do
          js.create_consumer("MISSING", durable_name: "c")
        end.to raise_error(NATS::JetStream::Error::StreamNotFound)
        expect do
          js.update_consumer("MISSING", durable_name: "c")
        end.to raise_error(NATS::JetStream::Error::StreamNotFound)
      end

      it "accepts a frozen config" do
        config = NATS::JetStream::API::ConsumerConfig.new(durable_name: "c", ack_wait: 30).freeze

        expect(js.create_consumer("ACTIONS", config).config.ack_wait).to eql(30)
        expect(js.add_consumer("ACTIONS", config).config.ack_wait).to eql(30)
      end

      it "still creates or updates with add_consumer" do
        js.add_consumer("ACTIONS", durable_name: "c", max_ack_pending: 10)

        expect(js.add_consumer("ACTIONS", durable_name: "c", max_ack_pending: 20).config.max_ack_pending).to eql(20)
      end

      it "leaves the caller's config unchanged" do
        config = NATS::JetStream::API::ConsumerConfig.new(durable_name: "c", ack_wait: 30,
          inactive_threshold: 60, idle_heartbeat: 5, deliver_subject: "deliver")

        js.add_consumer("ACTIONS", config)
        expect(config.to_h.slice(:ack_wait, :inactive_threshold, :idle_heartbeat))
          .to eql({ack_wait: 30, inactive_threshold: 60, idle_heartbeat: 5})

        # Sent again, the same config still means the same durations.
        config.max_ack_pending = 5
        expect(js.update_consumer("ACTIONS", config).config.ack_wait).to eql(30)
        expect(js.create_consumer("ACTIONS", config).config.ack_wait).to eql(30)
      end
    end

    describe "terminating a message" do
      let(:nc) { NATS.connect(@s.uri) }
      let(:js) { nc.jetstream }
      let(:advisories) { nc.subscribe("$JS.EVENT.ADVISORY.CONSUMER.MSG_TERMINATED.TERM.worker") }

      before do
        js.add_stream(name: "TERM", subjects: ["term"])
        js.publish("term", "a")
        advisories
      end

      after { nc.close }

      def next_advisory
        JSON.parse(advisories.next_msg(timeout: 5).data)
      end

      it "tells the server why the message was terminated" do
        js.pull_subscribe("term", "worker").fetch(1).first.term(reason: "malformed payload")

        advisory = next_advisory
        expect(advisory["stream_seq"]).to eql(1)
        expect(advisory["reason"]).to eql("malformed payload")
      end

      it "waits for the server when given a timeout and a reason" do
        msg = js.pull_subscribe("term", "worker").fetch(1).first

        expect(msg.term(reason: "malformed payload", timeout: 5)).to be_a(NATS::Msg)
        expect(next_advisory["reason"]).to eql("malformed payload")
      end

      it "terminates with a plain +TERM when the reason is blank" do
        msg = js.pull_subscribe("term", "worker").fetch(1).first
        # Servers before v2.10.4 ignore a +TERM followed by anything.
        sent = nc.subscribe(msg.reply)
        nc.flush

        msg.term(reason: " ")

        expect(sent.next_msg(timeout: 5).data).to eql("+TERM")
        expect(next_advisory).not_to have_key("reason")
      end

      it "terminates without a reason" do
        msg = js.pull_subscribe("term", "worker").fetch(1).first
        sent = nc.subscribe(msg.reply)
        nc.flush

        msg.term

        expect(sent.next_msg(timeout: 5).data).to eql("+TERM")
        advisory = next_advisory
        expect(advisory["stream_seq"]).to eql(1)
        expect(advisory).not_to have_key("reason")
      end
    end
  end
end
