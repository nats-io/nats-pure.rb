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

      # The settings of nats-server 2.11 to 2.14, as the server reports them.
      # Fast batches need nats-server 2.14.
      {
        "per-message TTLs" => {allow_msg_ttl: true},
        "subject delete markers" => {allow_msg_ttl: true, subject_delete_marker_ttl: 60 * ::NATS::NANOSECONDS},
        "counters" => {allow_msg_counter: true},
        "atomic batches" => {allow_atomic: true},
        "message schedules" => {allow_msg_schedules: true},
        "async persistence" => {persist_mode: "async"},
        "fast batches" => {allow_batched: true}
      }.each do |feature, settings|
        it "creates streams with #{feature}" do
          js.add_stream(name: "NEW", subjects: ["new"], **settings)

          expect(raw_stream_config("NEW").slice(*settings.keys)).to eql(settings)
          expect(js.stream_info("NEW").config.to_h.slice(*settings.keys)).to eql(settings)
        end

        it "keeps #{feature} when a fetched config is sent back as an update" do
          # Created without the client, so that only the update is tested.
          resp = nc.request("$JS.API.STREAM.CREATE.RMW", {name: "RMW", subjects: ["rmw"], **settings}.to_json)
          expect(JSON.parse(resp.data)).not_to have_key("error")

          config = js.stream_info("RMW").config
          config.max_msgs = 10
          js.update_stream(config)

          raw = raw_stream_config("RMW")
          expect(raw[:max_msgs]).to eql(10)
          expect(raw.slice(*settings.keys)).to eql(settings)
        end
      end

      it "refuses to disable per-message TTLs" do
        js.add_stream(name: "TTL", subjects: ["ttl"], allow_msg_ttl: true)
        config = js.stream_info("TTL").config
        config.allow_msg_ttl = false

        expect { js.update_stream(config) }.to raise_error(NATS::JetStream::Error::ServerError) { |e|
          expect(e.err_code).to eql(10052)
          expect(e.description).to eql("message TTL status can not be disabled")
        }
        expect(raw_stream_config("TTL")[:allow_msg_ttl]).to be(true)
      end

      it "sends the settings of nats-server 2.11 to 2.14 only when they are not the defaults" do
        creates = nc.subscribe("$JS.API.STREAM.CREATE.WIRE")
        updates = nc.subscribe("$JS.API.STREAM.UPDATE.WIRE")
        nc.flush
        defaults = {allow_msg_ttl: false, subject_delete_marker_ttl: 0, allow_msg_counter: false,
                    allow_atomic: false, allow_msg_schedules: false, persist_mode: "default", allow_batched: false}
        sent = ->(requests) { JSON.parse(requests.next_msg.data, symbolize_names: true).slice(*defaults.keys) }

        js.add_stream(name: "WIRE", subjects: ["wire"], **defaults)
        expect(sent.call(creates)).to be_empty

        # The server reports allow_msg_ttl even when it is false.
        config = js.stream_info("WIRE").config
        expect(config.allow_msg_ttl).to be(false)
        js.update_stream(config)
        expect(sent.call(updates)).to be_empty

        config.allow_msg_ttl = true
        config.allow_atomic = true
        js.update_stream(config)
        expect(sent.call(updates)).to eql({allow_msg_ttl: true, allow_atomic: true})
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

  describe "NATS v2.11+ Features" do
    before do
      @tmpdir = Dir.mktmpdir("ruby-jetstream")
      @s = NatsServerControl.new("nats://127.0.0.1:4852", "/tmp/test-nats.pid", "-js -sd=#{@tmpdir}")
      @s.start_server(true)
    end

    after do
      @s.kill_server
      FileUtils.remove_entry(@tmpdir)
    end

    let(:nc) { NATS.connect(@s.uri) }
    let(:js) { nc.jetstream }

    after { nc.close }

    describe "cluster info" do
      # Clustered streams and consumers also report when their leader was
      # elected, as cluster[:leader_since] (nats-server v2.12.0).
      it "reports the leader of a stream on a standalone server, and no cluster for its consumers" do
        js.add_stream(name: "STANDALONE", subjects: ["standalone"])
        js.add_consumer("STANDALONE", durable_name: "c")

        expect(js.stream_info("STANDALONE").cluster[:leader]).to be_a(String).and(satisfy { |leader| !leader.empty? })
        expect(js.consumer_info("STANDALONE", "c").cluster).to be_nil
      end
    end

    describe "pausing consumers" do
      before do
        js.add_stream(name: "PAUSE", subjects: ["pause"])
        js.publish("pause", "a")
      end

      it "creates a consumer paused until the given time" do
        pause_until = Time.now + 60
        # Frozen, as sending it must not convert the caller's Time to UTC.
        pause_until.freeze
        js.create_consumer("PAUSE", durable_name: "c", pause_until: pause_until)

        info = js.consumer_info("PAUSE", "c")
        expect(info.paused).to be(true)
        expect(info.pause_remaining).to be_between(55, 60)
        expect(Time.parse(info.config.pause_until)).to be_within(0.001).of(pause_until)
      end

      it "takes the pause time of a config as an RFC 3339 string" do
        pause_until = (Time.now.utc + 60).iso8601
        js.create_consumer("PAUSE", durable_name: "c", pause_until: pause_until)

        expect(js.consumer_info("PAUSE", "c").config.pause_until).to eql(pause_until)
      end

      it "pauses and resumes a consumer" do
        js.create_consumer("PAUSE", durable_name: "c")
        pause_until = Time.now + 60

        resp = js.pause_consumer("PAUSE", "c", pause_until)
        expect(resp.paused).to be(true)
        expect(resp.pause_until).to be_within(0.001).of(pause_until)
        expect(resp.pause_remaining).to be_between(55, 60)
        expect(js.consumer_info("PAUSE", "c").paused).to be(true)

        resp = js.resume_consumer("PAUSE", "c")
        expect(resp.to_h).to eql({paused: false, pause_until: nil, pause_remaining: nil})
        info = js.consumer_info("PAUSE", "c")
        expect(info.paused).to be_falsey
        expect(info.pause_remaining).to be_nil
        expect(info.config.pause_until).to be_nil
      end

      it "does not pause a consumer until a time in the past" do
        js.create_consumer("PAUSE", durable_name: "c")
        pause_until = Time.now - 60

        resp = js.pause_consumer("PAUSE", "c", pause_until)
        expect(resp.paused).to be(false)
        expect(resp.pause_until).to be_within(0.001).of(pause_until)
        expect(resp.pause_remaining).to be_nil
      end

      it "requires a time to pause a consumer until" do
        js.create_consumer("PAUSE", durable_name: "c", pause_until: Time.now + 60)

        expect { js.pause_consumer("PAUSE", "c", nil) }.to raise_error(ArgumentError)
        expect(js.consumer_info("PAUSE", "c").paused).to be(true)
      end

      it "takes the pause time as an RFC 3339 string" do
        js.create_consumer("PAUSE", durable_name: "c")
        pause_until = Time.now.utc + 60

        expect(js.pause_consumer("PAUSE", "c", pause_until.iso8601(3)).pause_until)
          .to be_within(0.001).of(pause_until)
      end

      it "delivers no messages while paused" do
        sub = js.pull_subscribe("pause", "c")
        js.pause_consumer("PAUSE", "c", Time.now + 60)

        expect { sub.fetch(1, timeout: 0.5) }.to raise_error(NATS::Timeout)

        js.resume_consumer("PAUSE", "c")
        expect(sub.fetch(1).map(&:data)).to eql(["a"])
      end

      it "keeps the pause through updates, whatever pause time they carry" do
        pause_until = (Time.now.utc + 60).iso8601(9)
        js.create_consumer("PAUSE", durable_name: "c", pause_until: pause_until)
        config = js.consumer_info("PAUSE", "c").config
        config.max_ack_pending = 10

        # The server only takes the pause time of a consumer it creates.
        [config, config.to_h.merge(pause_until: Time.now + 3600), config.to_h.merge(pause_until: nil)].each do |update|
          info = js.update_consumer("PAUSE", update)
          expect(info.paused).to be(true)
          expect(Time.parse(info.config.pause_until)).to eql(Time.parse(pause_until))
          expect(info.config.max_ack_pending).to eql(10)
        end
      end

      it "raises ConsumerNotFound for a consumer that does not exist" do
        expect do
          js.pause_consumer("PAUSE", "missing", Time.now + 60)
        end.to raise_error(NATS::JetStream::Error::ConsumerNotFound)
        expect do
          js.resume_consumer("PAUSE", "missing")
        end.to raise_error(NATS::JetStream::Error::ConsumerNotFound)
      end

      it "requires a stream and a consumer name" do
        expect { js.pause_consumer("", "c", Time.now) }.to raise_error(NATS::JetStream::Error::InvalidStreamName)
        expect { js.pause_consumer("PAUSE", nil, Time.now) }.to raise_error(NATS::JetStream::Error::InvalidConsumerName)
        expect { js.resume_consumer(nil, "c") }.to raise_error(NATS::JetStream::Error::InvalidStreamName)
        expect { js.resume_consumer("PAUSE", "") }.to raise_error(NATS::JetStream::Error::InvalidConsumerName)
      end
    end

    describe "priority groups" do
      before { js.add_stream(name: "PRIO", subjects: ["prio"]) }

      def publish(count)
        count.times { |i| js.publish("prio", i.to_s) }
      end

      it "creates consumers with priority groups" do
        info = js.create_consumer("PRIO", durable_name: "overflow",
          priority_policy: "overflow", priority_groups: ["A", "B"])

        expect(info.config.priority_policy).to eql("overflow")
        expect(info.config.priority_groups).to eql(["A", "B"])
        # The server keeps the state of the first group only.
        expect(info.priority_groups).to eql([NATS::JetStream::API::PriorityGroupState.new(group: "A")])

        info = js.create_consumer("PRIO", durable_name: "pinned",
          priority_policy: "pinned_client", priority_groups: ["A"], priority_timeout: 30)
        expect(info.config.priority_timeout).to eql(30)
        expect(js.consumer_info("PRIO", "pinned").config.priority_timeout).to eql(30)

        # Pinning defaults to two minutes.
        info = js.create_consumer("PRIO", durable_name: "default",
          priority_policy: "pinned_client", priority_groups: ["A"])
        expect(info.config.priority_timeout).to eql(120)
      end

      it "refuses invalid priority group settings" do
        {
          10159 => {priority_policy: "overflow"},
          10196 => {priority_groups: ["A"]},
          10162 => {priority_policy: "overflow", priority_groups: ["not valid"]},
          10197 => {priority_policy: "none", priority_timeout: 30},
          10178 => {priority_policy: "overflow", priority_groups: ["A"], deliver_subject: "push"}
        }.each do |err_code, config|
          expect do
            js.create_consumer("PRIO", config.merge(durable_name: "c"))
          end.to raise_error(NATS::JetStream::Error::BadRequest) { |e| expect(e.err_code).to eql(err_code) }
        end
      end

      it "requires the priority timeout in whole seconds" do
        expect do
          js.create_consumer("PRIO", durable_name: "c",
            priority_policy: "pinned_client", priority_groups: ["A"], priority_timeout: 1.5)
        end.to raise_error(ArgumentError)
      end

      it "keeps the priority settings when a fetched config is sent back as an update" do
        js.create_consumer("PRIO", durable_name: "c",
          priority_policy: "pinned_client", priority_groups: ["A"], priority_timeout: 30)

        config = js.consumer_info("PRIO", "c").config
        config.max_ack_pending = 10
        info = js.update_consumer("PRIO", config)

        expect(info.config.to_h.slice(:priority_policy, :priority_groups, :priority_timeout, :max_ack_pending))
          .to eql({priority_policy: "pinned_client", priority_groups: ["A"], priority_timeout: 30, max_ack_pending: 10})
      end

      it "requires the pulls of a consumer with a priority policy to name a group" do
        js.create_consumer("PRIO", durable_name: "c", priority_policy: "overflow", priority_groups: ["A"])
        publish(1)
        sub = js.pull_subscribe("prio", "c", stream: "PRIO")

        [1, 2].each do |batch|
          expect { sub.fetch(batch) }.to raise_error(NATS::JetStream::API::Error) { |e|
            expect(e.description).to eql("Bad Request - Priority Group missing")
          }
        end
        expect { sub.fetch(1, group: "B") }.to raise_error(NATS::JetStream::API::Error) { |e|
          expect(e.description).to eql("Bad Request - Invalid Priority Group")
        }
        expect(sub.fetch(1, group: "A").map(&:data)).to eql(["0"])
      end

      describe "with the overflow policy" do
        let(:sub) { js.pull_subscribe("prio", "c", stream: "PRIO") }
        # For the fetches that time out: the 408 that ends their pull can
        # come after they gave up, and a later fetch of more than one
        # message on the same subscription would take it for its own.
        let(:idle) { js.pull_subscribe("prio", "c", stream: "PRIO") }

        before do
          js.create_consumer("PRIO", durable_name: "c", priority_policy: "overflow", priority_groups: ["A"])
        end

        # The server may keep the pull of a fetch that timed out a little
        # longer than the fetch waited, and would deliver to it.
        def wait_for_expired_pulls
          eventually { expect(js.consumer_info("PRIO", "c").num_waiting).to eql(0) }
        end

        it "delivers only while at least min_pending messages are pending" do
          publish(5)
          expect { idle.fetch(2, group: "A", min_pending: 10, timeout: 0.5) }.to raise_error(NATS::Timeout)
          wait_for_expired_pulls

          publish(10)
          expect(sub.fetch(2, group: "A", min_pending: 10).map(&:data)).to eql(["0", "1"])
        end

        it "delivers only while at least min_ack_pending messages await acks" do
          publish(10)
          sub.fetch(2, group: "A")
          expect { idle.fetch(2, group: "A", min_ack_pending: 5, timeout: 0.5) }.to raise_error(NATS::Timeout)
          wait_for_expired_pulls

          sub.fetch(3, group: "A")
          expect(sub.fetch(2, group: "A", min_ack_pending: 5).map(&:data)).to eql(["5", "6"])
        end

        it "sends the priority settings with its pull, whether it waits or not" do
          requests = nc.subscribe("$JS.API.CONSUMER.MSG.NEXT.PRIO.c")
          nc.flush

          expect { sub.fetch(2, group: "A", min_pending: 10, min_ack_pending: 20, timeout: 0.5) }
            .to raise_error(NATS::Timeout)
          expect(sub.fetch(2, group: "A", min_pending: 10, min_ack_pending: 20, no_wait: true)).to eql([])

          pulls = Array.new(2) { JSON.parse(requests.next_msg.data, symbolize_names: true) }
          expect(pulls.map { |pull| pull.slice(:no_wait, :group, :min_pending, :min_ack_pending) }).to eql([
            {group: "A", min_pending: 10, min_ack_pending: 20},
            {no_wait: true, group: "A", min_pending: 10, min_ack_pending: 20}
          ])
        end

        it "requires the minimums to be positive integers" do
          [0, 1.5, "3"].each do |min|
            expect { sub.fetch(1, group: "A", min_pending: min) }.to raise_error(ArgumentError, /min_pending/)
            expect { sub.fetch(1, group: "A", min_ack_pending: min) }.to raise_error(ArgumentError, /min_ack_pending/)
          end
        end

        it "refuses minimums for consumers without the overflow policy" do
          js.create_consumer("PRIO", durable_name: "pinned", priority_policy: "pinned_client", priority_groups: ["A"])
          sub = js.pull_subscribe("prio", "pinned", stream: "PRIO")

          expect { sub.fetch(1, group: "A", min_pending: 1) }.to raise_error(NATS::JetStream::API::Error) { |e|
            expect(e.description).to eql("Bad Request - Not a Overflow Priority consumer")
          }
        end
      end

      describe "with the pinned_client policy" do
        let(:sub) { js.pull_subscribe("prio", "c", stream: "PRIO") }

        def create_consumer(config = {})
          js.create_consumer("PRIO", {durable_name: "c",
                                      priority_policy: "pinned_client", priority_groups: ["A"]}.merge(config))
        end

        def pin_ids(msgs)
          msgs.map { |msg| msg.header["Nats-Pin-Id"] }.uniq
        end

        # A reply subject of the subscription, as for a pull of an earlier fetch.
        def earlier_reply(sub)
          sub.subject.sub("*", "earlier")
        end

        def pinned_client_id
          js.consumer_info("PRIO", "c").priority_groups.first.pinned_client_id
        end

        it "pins the first subscription to pull, while the others wait" do
          create_consumer
          publish(10)

          msgs = sub.fetch(3, group: "A")
          expect(msgs.map(&:data)).to eql(["0", "1", "2"])
          pin_id = pin_ids(msgs).first
          expect(pin_ids(msgs)).to eql([pin_id]).and(eql([pinned_client_id]))
          expect(js.consumer_info("PRIO", "c").priority_groups.first.pinned_ts).to be_within(60).of(Time.now)

          other = js.pull_subscribe("prio", "c", stream: "PRIO")
          expect { other.fetch(3, group: "A", timeout: 0.5) }.to raise_error(NATS::Timeout)

          msgs = sub.fetch(3, group: "A")
          expect(msgs.map(&:data)).to eql(["3", "4", "5"])
          expect(pin_ids(msgs)).to eql([pin_id])
        end

        it "sends its pin id with its pull, whether it waits or not" do
          create_consumer
          publish(1)
          pin_id = pin_ids(sub.fetch(1, group: "A")).first
          requests = nc.subscribe("$JS.API.CONSUMER.MSG.NEXT.PRIO.c")
          nc.flush

          expect { sub.fetch(2, group: "A", timeout: 0.5) }.to raise_error(NATS::Timeout)
          expect(sub.fetch(2, group: "A", no_wait: true)).to eql([])

          pulls = Array.new(2) { JSON.parse(requests.next_msg.data, symbolize_names: true) }
          expect(pulls.map { |pull| pull.slice(:no_wait, :group, :id) }).to eql([
            {group: "A", id: pin_id},
            {no_wait: true, group: "A", id: pin_id}
          ])
        end

        it "raises PinIdMismatch once the pin expired, then pins the subscription again" do
          create_consumer(priority_timeout: 1)
          publish(10)
          pin_id = pin_ids(sub.fetch(2, group: "A")).first

          # Wait out the pin, which lasts a second without pulls.
          sleep 1.5
          expect { sub.fetch(2, group: "A") }.to raise_error(NATS::JetStream::Error::PinIdMismatch) { |e|
            expect(e).to be_a(NATS::JetStream::API::Error)
            expect(e.code).to eql(423)
          }

          msgs = sub.fetch(2, group: "A")
          expect(msgs.map(&:data)).to eql(["2", "3"])
          expect(pin_ids(msgs)).to eql([pinned_client_id])
          expect(pin_ids(msgs)).not_to eql([pin_id])
        end

        it "keeps its pin after fetches that timed out" do
          create_consumer
          js.publish("prio", "first")
          pin_id = pin_ids(sub.fetch(1, group: "A")).first
          [2, 1].each do |batch|
            expect { sub.fetch(batch, group: "A", timeout: 0.5) }.to raise_error(NATS::Timeout)
          end
          other = js.pull_subscribe("prio", "c", stream: "PRIO")
          other_fetch = Thread.new { other.fetch(1, group: "A", timeout: 1) }
          eventually { expect(js.consumer_info("PRIO", "c").num_waiting).to eql(1) }
          js.publish("prio", "second")

          msgs = sub.fetch(1, group: "A", timeout: 2)
          expect(msgs.map(&:data)).to eql(["second"])
          expect(pin_ids(msgs)).to eql([pin_id])
          expect { other_fetch.value }.to raise_error(NATS::Timeout)
        end

        it "unpins a group" do
          create_consumer
          publish(10)
          pin_id = pin_ids(sub.fetch(1, group: "A")).first

          expect(js.unpin_consumer("PRIO", "c", "A")).to be(true)
          expect(js.consumer_info("PRIO", "c").priority_groups)
            .to eql([NATS::JetStream::API::PriorityGroupState.new(group: "A")])

          expect { sub.fetch(1, group: "A") }.to raise_error(NATS::JetStream::Error::PinIdMismatch)
          msgs = sub.fetch(1, group: "A")
          expect(msgs.map(&:data)).to eql(["1"])
          expect(pin_ids(msgs)).to eql([pinned_client_id])
          expect(pin_ids(msgs)).not_to eql([pin_id])
        end

        it "returns the messages a fetch got before the subscription was unpinned" do
          create_consumer
          js.publish("prio", "first")
          pin_id = pin_ids(sub.fetch(1, group: "A")).first
          fetch = Thread.new { sub.fetch(5, group: "A", timeout: 5) }
          eventually { expect(js.consumer_info("PRIO", "c").num_waiting).to eql(1) }

          js.publish("prio", "second")
          js.publish("prio", "third")
          eventually { expect(js.consumer_info("PRIO", "c").num_ack_pending).to eql(3) }
          js.unpin_consumer("PRIO", "c", "A")
          # The server turns the waiting pull away once it has a message for it.
          js.publish("prio", "fourth")

          # The fetch ends there, long before its timeout.
          expect(fetch.join(2.5)).to be(fetch)
          msgs = fetch.value
          expect(msgs.map(&:data)).to eql(["second", "third"])
          expect(pin_ids(msgs)).to eql([pin_id])

          msgs = sub.fetch(1, group: "A")
          expect(msgs.map(&:data)).to eql(["fourth"])
          expect(pin_ids(msgs)).not_to eql([pin_id])
        end

        describe "when a pull left over from an earlier fetch is turned away" do
          # Such a pull is answered after its fetch ended, into the
          # subscription, as when the fetch timed out a little before it.
          def leftover_pull(pin_id, batch)
            nc.publish("$JS.API.CONSUMER.MSG.NEXT.PRIO.c",
              {batch: batch, expires: 5_000_000_000, group: "A", id: pin_id}.to_json, earlier_reply(sub))
          end

          it "pulls without the stale pin id on the next fetch, which pins the subscription again" do
            create_consumer
            js.publish("prio", "first")
            pin_id = pin_ids(sub.fetch(1, group: "A")).first

            leftover_pull(pin_id, 1)
            js.unpin_consumer("PRIO", "c", "A")
            js.publish("prio", "second")
            wait_until { sub.pending_queue.size == 1 }
            requests = nc.subscribe("$JS.API.CONSUMER.MSG.NEXT.PRIO.c")
            nc.flush

            # The 423 ended a pull of an earlier fetch, not of this one.
            msgs = sub.fetch(1, group: "A")
            expect(msgs.map(&:data)).to eql(["second"])
            expect(pin_ids(msgs)).not_to eql([pin_id])
            nc.flush
            pulls = Array.new(requests.pending_queue.size) { JSON.parse(requests.next_msg.data, symbolize_names: true) }
            expect(pulls.map { |pull| pull.slice(:group, :id) }).to eql([{group: "A"}])
          end

          it "takes the messages the pull got before, and pulls the rest without its pin id" do
            create_consumer
            js.publish("prio", "first")
            pin_id = pin_ids(sub.fetch(1, group: "A")).first

            leftover_pull(pin_id, 2)
            js.publish("prio", "second")
            wait_until { sub.pending_queue.size == 1 }
            js.unpin_consumer("PRIO", "c", "A")
            js.publish("prio", "third")
            wait_until { sub.pending_queue.size == 2 }

            msgs = sub.fetch(2, group: "A")
            expect(msgs.map(&:data)).to eql(["second", "third"])
            expect(pin_ids(msgs).first).to eql(pin_id)
            expect(pin_ids(msgs).last).not_to eql(pin_id)
          end

          it "waits on standby on the next fetch once another subscription is pinned" do
            create_consumer
            js.publish("prio", "first")
            pin_id = pin_ids(sub.fetch(1, group: "A")).first
            leftover_pull(pin_id, 1)
            js.unpin_consumer("PRIO", "c", "A")
            js.publish("prio", "second")
            wait_until { sub.pending_queue.size == 1 }
            other = js.pull_subscribe("prio", "c", stream: "PRIO")
            expect(other.fetch(1, group: "A").map(&:data)).to eql(["second"])

            expect { sub.fetch(2, group: "A", timeout: 0.5) }.to raise_error(NATS::Timeout)
          end

          it "returns the messages the next fetch took when its own pull is turned away" do
            create_consumer
            js.publish("prio", "first")
            pin_id = pin_ids(sub.fetch(1, group: "A")).first
            leftover_pull(pin_id, 1)
            js.publish("prio", "left")
            wait_until { sub.pending_queue.size == 1 }
            js.unpin_consumer("PRIO", "c", "A")
            other = js.pull_subscribe("prio", "c", stream: "PRIO")
            js.publish("prio", "second")
            expect(other.fetch(1, group: "A").map(&:data)).to eql(["second"])

            # It pulls with the pin id of the message it took, which the
            # server turns away (423), as another subscription is pinned.
            msgs = sub.fetch(2, group: "A")
            expect(msgs.map(&:data)).to eql(["left"])
            expect(pin_ids(msgs)).to eql([pin_id])
          end
        end

        it "counts the messages a pull left over got pinned with, and pulls the rest with their pin" do
          create_consumer
          js.publish("prio", "first")
          pin_id = pin_ids(sub.fetch(1, group: "A")).first
          js.unpin_consumer("PRIO", "c", "A")
          # A pull without a pin id, left over from before the subscription
          # was pinned, gets the group pinned to it again, with a new pin.
          nc.publish("$JS.API.CONSUMER.MSG.NEXT.PRIO.c",
            {batch: 1, expires: 5_000_000_000, group: "A"}.to_json, earlier_reply(sub))
          js.publish("prio", "second")
          wait_until { sub.pending_queue.size == 1 }
          js.publish("prio", "third")
          requests = nc.subscribe("$JS.API.CONSUMER.MSG.NEXT.PRIO.c")
          nc.flush

          msgs = sub.fetch(2, group: "A")

          expect(msgs.map(&:data)).to eql(["second", "third"])
          expect(pin_ids(msgs)).to eql([pinned_client_id])
          expect(pin_ids(msgs)).not_to eql([pin_id])
          pull = JSON.parse(requests.next_msg.data, symbolize_names: true)
          expect(pull.slice(:batch, :id)).to eql({batch: 1, id: pinned_client_id})
        end

        it "refuses to unpin a group the consumer does not have" do
          create_consumer

          expect { js.unpin_consumer("PRIO", "c", "B") }.to raise_error(NATS::JetStream::Error::BadRequest) { |e|
            expect(e.err_code).to eql(10160)
          }
        end

        it "raises ConsumerNotFound when unpinning a consumer that does not exist" do
          expect { js.unpin_consumer("PRIO", "missing", "A") }.to raise_error(NATS::JetStream::Error::ConsumerNotFound)
        end

        it "requires a stream and a consumer name to unpin" do
          expect { js.unpin_consumer("", "c", "A") }.to raise_error(NATS::JetStream::Error::InvalidStreamName)
          expect { js.unpin_consumer("PRIO", nil, "A") }.to raise_error(NATS::JetStream::Error::InvalidConsumerName)
        end
      end

      # Requires nats-server v2.12.0.
      describe "with the prioritized policy" do
        before do
          info = js.create_consumer("PRIO", durable_name: "c", priority_policy: "prioritized", priority_groups: ["A"])
          expect(info.config.priority_policy).to eql("prioritized")
        end

        def num_waiting
          js.consumer_info("PRIO", "c").num_waiting
        end

        it "serves the pulls with the highest priority first" do
          low, high = Array.new(2) { js.pull_subscribe("prio", "c", stream: "PRIO") }
          low_fetch = Thread.new { low.fetch(5, group: "A", priority: 1, timeout: 5) }
          eventually { expect(num_waiting).to eql(1) }
          high_fetch = Thread.new { high.fetch(5, group: "A", priority: 0, timeout: 5) }
          eventually { expect(num_waiting).to eql(2) }

          publish(10)

          expect(high_fetch.value.map(&:data)).to eql(%w[0 1 2 3 4])
          expect(low_fetch.value.map(&:data)).to eql(%w[5 6 7 8 9])
        end

        it "refuses priorities above 9" do
          sub = js.pull_subscribe("prio", "c", stream: "PRIO")

          expect { sub.fetch(1, group: "A", priority: 10) }.to raise_error(NATS::JetStream::API::Error) { |e|
            expect(e.description).to eql("Bad Request - Priority must be between 0 and 9")
          }
        end
      end
    end

    # Requires nats-server v2.14.0.
    describe "resetting consumers" do
      before do
        js.add_stream(name: "RESET", subjects: ["reset"])
        10.times { |i| js.publish("reset", i.to_s) }
      end

      def next_stream_seq(sub)
        sub.fetch(1).first.metadata.sequence.to_a
      end

      it "redelivers from the message after the ack floor" do
        js.create_consumer("RESET", durable_name: "c")
        sub = js.pull_subscribe("reset", "c", stream: "RESET")
        sub.fetch(4).first(2).each(&:ack_sync)

        resp = js.reset_consumer("RESET", "c")

        expect(resp.reset_seq).to eql(3)
        expect(resp.info).to be_a(NATS::JetStream::API::ConsumerInfo)
        expect(resp.info.name).to eql("c")
        expect(resp.info.num_ack_pending).to eql(0)
        expect(resp.info.num_pending).to eql(8)
        expect(resp.info.config).to eql(js.consumer_info("RESET", "c").config)
        expect(resp).to be_frozen
        # The consumer sequence starts again at 1.
        expect(next_stream_seq(sub)).to eql([3, 1])
      end

      it "resets to the given stream sequence" do
        js.create_consumer("RESET", durable_name: "c")
        sub = js.pull_subscribe("reset", "c", stream: "RESET")
        params = {seq: 7}

        resp = js.reset_consumer("RESET", "c", params)

        expect(resp.reset_seq).to eql(7)
        expect(resp.info.num_pending).to eql(4)
        expect(next_stream_seq(sub)).to eql([7, 1])
        expect(params).to eql({seq: 7})
      end

      it "refuses to reset a consumer to before its start sequence" do
        js.create_consumer("RESET", durable_name: "c", deliver_policy: "by_start_sequence", opt_start_seq: 5)

        expect do
          js.reset_consumer("RESET", "c", seq: 4)
        end.to raise_error(NATS::JetStream::Error::ConsumerInvalidReset) { |e|
          expect(e).to be_a(NATS::JetStream::Error::BadRequest)
          expect(e.err_code).to eql(10204)
        }
        expect(js.reset_consumer("RESET", "c", seq: 5).reset_seq).to eql(5)
      end

      it "refuses to reset a consumer to before its start time" do
        js.create_consumer("RESET", durable_name: "c", deliver_policy: "by_start_time",
          opt_start_time: Time.now.utc.iso8601(9))
        2.times { |i| js.publish("reset", "late #{i}") }

        expect do
          js.reset_consumer("RESET", "c", seq: 10)
        end.to raise_error(NATS::JetStream::Error::ConsumerInvalidReset) { |e| expect(e.err_code).to eql(10204) }
        expect(js.reset_consumer("RESET", "c", seq: 11).reset_seq).to eql(11)
      end

      it "requires the sequence to be an integer of 0 or more" do
        js.create_consumer("RESET", durable_name: "c")

        [-1, 1.5, "3"].each do |seq|
          expect { js.reset_consumer("RESET", "c", seq: seq) }.to raise_error(ArgumentError, /seq/)
        end
        # As without a sequence, 0 resets the consumer to its ack floor.
        expect(js.reset_consumer("RESET", "c", seq: 0).reset_seq).to eql(1)
      end

      it "resets a consumer that starts with new messages only to its ack floor" do
        js.create_consumer("RESET", durable_name: "c", deliver_policy: "new")

        expect do
          js.reset_consumer("RESET", "c", seq: 1)
        end.to raise_error(NATS::JetStream::Error::ConsumerInvalidReset)
        expect(js.reset_consumer("RESET", "c").reset_seq).to eql(11)
      end

      it "times out for a consumer that does not exist" do
        expect { js.reset_consumer("RESET", "missing", timeout: 0.5) }.to raise_error(NATS::Timeout)
      end

      it "requires a stream and a consumer name" do
        expect { js.reset_consumer(nil, "c") }.to raise_error(NATS::JetStream::Error::InvalidStreamName)
        expect { js.reset_consumer("RESET", "") }.to raise_error(NATS::JetStream::Error::InvalidConsumerName)
      end
    end

    # Requires nats-server v2.14.0.
    describe "flow control ack policy" do
      before { js.add_stream(name: "AFC", subjects: ["afc"]) }

      it "creates push consumers acknowledged by flow control" do
        created = js.create_consumer("AFC", durable_name: "c", ack_policy: "flow_control", deliver_subject: "afc.deliver")

        # Such consumers have no ack wait, and the server turns on flow
        # control and heartbeats for them.
        [created, js.consumer_info("AFC", "c")].each do |info|
          expect(info.config.to_h.slice(:ack_policy, :ack_wait, :flow_control, :idle_heartbeat))
            .to eql({ack_policy: "flow_control", ack_wait: nil, flow_control: true, idle_heartbeat: 1})
        end
      end

      it "refuses pull consumers" do
        expect do
          js.create_consumer("AFC", durable_name: "c", ack_policy: "flow_control")
        end.to raise_error(NATS::JetStream::Error::BadRequest) { |e| expect(e.err_code).to eql(10218) }
      end
    end

    # A fetch of more than one message first asks for the messages that
    # are pending, without waiting. The server turns such a pull away,
    # with 408 Requests Pending, when other pulls wait for more messages
    # than are pending.
    describe "fetching while other pulls wait for more messages than are pending" do
      let(:sub) { js.pull_subscribe("waiting", "c", stream: "WAITING") }
      let(:other) { js.pull_subscribe("waiting", "c", stream: "WAITING") }

      before { js.add_stream(name: "WAITING", subjects: ["waiting"]) }

      def num_waiting
        js.consumer_info("WAITING", "c").num_waiting
      end

      def publish(count)
        count.times { |i| js.publish("waiting", i.to_s) }
      end

      it "waits for the messages" do
        js.create_consumer("WAITING", durable_name: "c")
        other_fetch = Thread.new { other.fetch(10, timeout: 1) }
        eventually { expect(num_waiting).to eql(1) }
        # Paused, the consumer keeps its messages pending.
        js.pause_consumer("WAITING", "c", Time.now + 60)
        publish(5)

        fetch = Thread.new { sub.fetch(3, timeout: 5) }
        expect { other_fetch.value }.to raise_error(NATS::Timeout)
        expect(fetch).to be_alive
        eventually { expect(num_waiting).to eql(1) }
        js.resume_consumer("WAITING", "c")
        # The server delivers again once it has a new message.
        js.publish("waiting", "5")

        expect(fetch.value.map(&:data)).to eql(%w[0 1 2])
      end

      it "waits for the messages of a pinned subscription while another one is on standby" do
        js.create_consumer("WAITING", durable_name: "c", priority_policy: "pinned_client", priority_groups: ["A"])
        js.publish("waiting", "pin")
        sub.fetch(1, group: "A")
        other_fetch = Thread.new { other.fetch(10, group: "A", timeout: 1.5) }
        eventually { expect(num_waiting).to eql(1) }
        publish(5)

        expect(sub.fetch(3, group: "A").map(&:data)).to eql(%w[0 1 2])
        expect { other_fetch.value }.to raise_error(NATS::Timeout)
      end

      it "waits for the messages while pulls with a higher overflow minimum wait" do
        js.create_consumer("WAITING", durable_name: "c", priority_policy: "overflow", priority_groups: ["A"])
        other_fetch = Thread.new { other.fetch(10, group: "A", min_pending: 100, timeout: 1.5) }
        eventually { expect(num_waiting).to eql(1) }
        publish(5)

        expect(sub.fetch(3, group: "A").map(&:data)).to eql(%w[0 1 2])
        expect { other_fetch.value }.to raise_error(NATS::Timeout)
      end
    end
  end
end
