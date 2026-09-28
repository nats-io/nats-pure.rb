# frozen_string_literal: true

describe "JetStream" do
  describe "Publish" do
    before do
      @tmpdir = Dir.mktmpdir("ruby-jetstream")
      @s = NatsServerControl.new("nats://127.0.0.1:4524", "/tmp/test-nats.pid", "-js -sd=#{@tmpdir}")
      @s.start_server(true)
    end

    after do
      @s.kill_server
      FileUtils.remove_entry(@tmpdir)
    end

    it "should publish messages to a stream" do
      nc = NATS.connect(@s.uri)

      # Create sample Stream and pull based consumer from JetStream
      # from which it will be attempted to fetch messages using no_wait.
      stream_req = {
        name: "foojs",
        subjects: ["foo.js"]
      }

      # Create the stream.
      resp = nc.request("$JS.API.STREAM.CREATE.foojs", stream_req.to_json)
      expect(resp).to_not be_nil

      # Get JetStream context.
      js = nc.jetstream

      1.upto(100) do |n|
        ack = js.publish("foo.js", "hello world")
        expect(ack[:stream]).to eql("foojs")
        expect(ack[:seq]).to eql(n)
        expect(ack.stream).to eql("foojs")
        expect(ack.seq).to eql(n)
      end

      # Assert stream name.
      expect do
        js.publish("foo.js", "hello world", stream: "bar")
      end.to raise_error(NATS::JetStream::API::Error)

      begin
        js.publish("foo.js", "hello world", stream: "bar")
      rescue NATS::JetStream::API::Error => e
        expect(e.code).to eql(400)
      end

      expect do
        js.publish("foo.bar", "hello world")
      end.to raise_error(NATS::JetStream::Error::NoStreamResponse)

      nc.close
    end

    it "should return the counter value in the pub ack" do
      nc = NATS.connect(@s.uri)
      js = nc.jetstream
      js.add_stream(name: "CTR", subjects: ["ctr"], allow_msg_counter: true)

      ack = js.publish("ctr", header: {"Nats-Incr" => "+1"})
      expect(ack.seq).to eql(1)
      expect(ack.val).to eql("1")

      ack = js.publish("ctr", header: {"Nats-Incr" => "+2"})
      expect(ack.seq).to eql(2)
      expect(ack.val).to eql("3")

      nc.close
    end

    it "should return the batch id and size in the pub ack of an atomic batch commit" do
      nc = NATS.connect(@s.uri)
      js = nc.jetstream
      js.add_stream(name: "ATOMIC", subjects: ["atomic"], allow_atomic: true)

      js.publish("atomic", "not batched")
      ack = js.publish("atomic", "batched", header: {
        NATS::JetStream::Header::BATCH_ID => "b1",
        NATS::JetStream::Header::BATCH_SEQUENCE => "1",
        NATS::JetStream::Header::BATCH_COMMIT => "1"
      })
      expect(ack.seq).to eql(2)
      expect(ack.batch).to eql("b1")
      expect(ack.count).to eql(1)

      nc.close
    end

    it "should commit an atomic batch without storing the commit message" do
      nc = NATS.connect(@s.uri)
      js = nc.jetstream
      js.add_stream(name: "EOB", subjects: ["eob"], allow_atomic: true)

      # Only the commit is acked: the other messages of a batch go without a reply.
      nc.publish("eob", "first", header: {
        NATS::JetStream::Header::BATCH_ID => "b1",
        NATS::JetStream::Header::BATCH_SEQUENCE => "1"
      })
      ack = js.publish("eob", "", header: {
        NATS::JetStream::Header::BATCH_ID => "b1",
        NATS::JetStream::Header::BATCH_SEQUENCE => "2",
        NATS::JetStream::Header::BATCH_COMMIT => "eob"
      })
      expect(ack.seq).to eql(1)
      expect(ack.count).to eql(1)
      expect(js.get_msg("EOB", seq: 1).data).to eql("first")
      expect(js.stream_info("EOB").state.messages).to eql(1)

      nc.close
    end

    describe "with a TTL" do
      let(:nc) { NATS.connect(@s.uri) }
      let(:js) { nc.jetstream }

      before { js.add_stream(name: "TTL", subjects: ["ttl"], allow_msg_ttl: true) }
      after { nc.close }

      it "removes the message once its TTL has passed" do
        ack = js.publish("ttl", "short lived", ttl: 1)

        expect(js.get_msg("TTL", seq: ack.seq).headers).to include(NATS::JetStream::Header::MSG_TTL => "1")
        eventually { expect { js.get_msg("TTL", seq: ack.seq) }.to raise_error(NATS::JetStream::Error::NotFound) }
      end

      it "keeps a message that never expires past the max age of the stream" do
        js.add_stream(name: "AGED", subjects: ["aged"], allow_msg_ttl: true, max_age: ::NATS::NANOSECONDS)
        kept = js.publish("aged", "kept", ttl: :never)
        aged = js.publish("aged", "aged")

        eventually { expect { js.get_msg("AGED", seq: aged.seq) }.to raise_error(NATS::JetStream::Error::NotFound) }
        expect(js.get_msg("AGED", seq: kept.seq).headers).to include(NATS::JetStream::Header::MSG_TTL => "never")
      end

      it "adds the TTL to the header, leaving the given header unchanged" do
        header = {"color" => "blue"}

        ack = js.publish("ttl", "x", header: header, stream: "TTL", ttl: 60)

        expect(header).to eql({"color" => "blue"})
        expect(js.get_msg("TTL", seq: ack.seq).headers)
          .to include("color" => "blue", NATS::JetStream::Header::MSG_TTL => "60")
      end

      it "refuses a TTL that is not a whole number of seconds from 1 to 2**32, or :never" do
        [0, -1, 1.5, "5", "never", :forever, 2**32 + 1].each do |ttl|
          expect { js.publish("ttl", "x", ttl: ttl) }.to raise_error(ArgumentError)
        end
        expect(js.stream_info("TTL").state.messages).to eql(0)

        # Longer TTLs overflow in the server, which then removes the message at once.
        ack = js.publish("ttl", "x", ttl: 2**32)
        expect(js.get_msg("TTL", seq: ack.seq).headers).to include(NATS::JetStream::Header::MSG_TTL => "4294967296")
      end

      it "lets the options replace the same headers in the given header" do
        header = {NATS::JetStream::Header::EXPECTED_STREAM => "OTHER", NATS::JetStream::Header::MSG_TTL => "5"}

        ack = js.publish("ttl", "x", header: header, stream: "TTL", ttl: 60)

        expect(js.get_msg("TTL", seq: ack.seq).headers).to include(
          NATS::JetStream::Header::EXPECTED_STREAM => "TTL",
          NATS::JetStream::Header::MSG_TTL => "60"
        )
      end

      it "expects no stream when the stream option is false or nil" do
        [false, nil].each do |stream|
          ack = js.publish("ttl", "x", stream: stream)
          expect(js.get_msg("TTL", seq: ack.seq).headers).to be_nil
        end
      end

      it "fails on a stream that does not allow TTLs" do
        js.add_stream(name: "PLAIN", subjects: ["plain"])

        expect do
          js.publish("plain", "x", ttl: 5)
        end.to raise_error(NATS::JetStream::Error::BadRequest) { |e| expect(e.err_code).to eql(10166) }
      end
    end

    describe "with a schedule" do
      let(:nc) { NATS.connect(@s.uri) }
      let(:js) { nc.jetstream }

      before do
        js.add_stream(name: "SCHEDULES", subjects: ["schedules.>", "targets.>", "sources.>"],
          allow_msg_schedules: true, allow_msg_ttl: true)
      end

      after { nc.close }

      # The header stored with a published message.
      def stored_header(ack)
        js.get_msg("SCHEDULES", seq: ack.seq).headers
      end

      # The first message that a schedule publishes to the target.
      def scheduled_msg(target)
        wait_until do
          msg = js.get_last_msg("SCHEDULES", target)
          msg if msg.headers&.key?(NATS::JetStream::Header::SCHEDULER)
        rescue NATS::JetStream::Error::NotFound
          nil
        end
      end

      it "publishes the message to the target at the given time" do
        at = Time.now + 1
        ack = js.publish("schedules.at", "hello", schedule: {at: at, target: "targets.at"})

        expect(stored_header(ack)).to include(
          NATS::JetStream::Header::SCHEDULE => "@at #{at.getutc.iso8601(9)}",
          NATS::JetStream::Header::SCHEDULE_TARGET => "targets.at"
        )
        msg = scheduled_msg("targets.at")
        expect(msg.data).to eql("hello")
        expect(msg.headers).to include(
          NATS::JetStream::Header::SCHEDULER => "schedules.at",
          NATS::JetStream::Header::SCHEDULE_NEXT => "purge"
        )
      end

      it "sends the time in UTC to the nanosecond, leaving the given time unchanged" do
        at = Time.new(2030, 1, 2, 3, 4, 5.5, "+02:00")

        ack = js.publish("schedules.at", "", schedule: {at: at, target: "targets.at"})

        expect(stored_header(ack)).to include(NATS::JetStream::Header::SCHEDULE => "@at 2030-01-02T01:04:05.500000000Z")
        expect(at.utc_offset).to eql(7200)
      end

      it "publishes the message to the target every so many seconds" do
        ack = js.publish("schedules.every", "tick", schedule: {every: 1, target: "targets.every"})

        expect(stored_header(ack)).to include(NATS::JetStream::Header::SCHEDULE => "@every 1s")
        msg = scheduled_msg("targets.every")
        expect(msg.data).to eql("tick")
        expect(Time.iso8601(msg.headers[NATS::JetStream::Header::SCHEDULE_NEXT])).to be_within(5).of(Time.now)
      end

      it "publishes the message on a cron schedule in a time zone" do
        ack = js.publish("schedules.cron", "tick",
          schedule: {cron: "* * * * * *", time_zone: "Europe/Warsaw", target: "targets.cron"})

        expect(stored_header(ack)).to include(
          NATS::JetStream::Header::SCHEDULE => "* * * * * *",
          NATS::JetStream::Header::SCHEDULE_TIME_ZONE => "Europe/Warsaw"
        )
        expect(scheduled_msg("targets.cron").data).to eql("tick")

        ack = js.publish("schedules.hourly", "", schedule: {cron: "@hourly", target: "targets.hourly"})
        expect(stored_header(ack)).to include(NATS::JetStream::Header::SCHEDULE => "@hourly")
      end

      it "publishes the last message of the source instead" do
        js.publish("sources.a", "sampled")

        js.publish("schedules.sample", "own", schedule: {at: Time.now, target: "targets.sample", source: "sources.a"})

        expect(scheduled_msg("targets.sample").data).to eql("sampled")
      end

      it "publishes messages with a TTL" do
        js.publish("schedules.ttl", "", schedule: {at: Time.now, target: "targets.ttl", ttl: 60})

        expect(scheduled_msg("targets.ttl").headers).to include(NATS::JetStream::Header::MSG_TTL => "60")

        ack = js.publish("schedules.never", "", schedule: {at: Time.now + 3600, target: "targets.never", ttl: :never})
        expect(stored_header(ack)).to include(NATS::JetStream::Header::SCHEDULE_TTL => "never")
      end

      it "rolls up the target" do
        earlier = js.publish("targets.rollup", "earlier")

        js.publish("schedules.rollup", "", schedule: {at: Time.now, target: "targets.rollup", rollup: true})

        expect(scheduled_msg("targets.rollup").headers).to include(NATS::JetStream::Header::ROLLUP => "sub")
        expect { js.get_msg("SCHEDULES", seq: earlier.seq) }.to raise_error(NATS::JetStream::Error::NotFound)

        ack = js.publish("schedules.kept", "", schedule: {at: Time.now + 3600, target: "targets.kept", rollup: false})
        expect(stored_header(ack)).not_to have_key(NATS::JetStream::Header::SCHEDULE_ROLLUP)
      end

      it "refuses an invalid schedule before sending it" do
        at = Time.now + 3600
        [
          {target: "targets.a"},
          {at: at, every: 60, target: "targets.a"},
          {at: at},
          {at: at, target: ""},
          {at: at.iso8601, target: "targets.a"},
          {every: 0, target: "targets.a"},
          {every: 1.5, target: "targets.a"},
          {cron: "", target: "targets.a"},
          {cron: 60, target: "targets.a"},
          {at: at, target: "targets.a", ttl: 0},
          {at: at, target: "targets.a", rollup: "sub"},
          {at: at, target: "targets.a", timezone: "UTC"},
          {at: at, every: false, target: "targets.a"},
          {at: at, target: "targets.a", source: ""},
          {at: at, target: "targets.a", source: :sources},
          {at: at, target: "targets.a", time_zone: "UTC"},
          {every: 60, target: "targets.a", time_zone: "UTC"},
          {cron: "@daily", target: "targets.a", time_zone: ""},
          "@daily",
          [[:cron, "@daily"], [:target, "targets.a"]]
        ].each do |schedule|
          expect { js.publish("schedules.a", "", schedule: schedule) }.to raise_error(ArgumentError)
        end
        expect(js.stream_info("SCHEDULES").state.messages).to eql(0)
      end

      it "fails on a schedule that the server does not take" do
        expect do
          js.publish("schedules.a", "", schedule: {cron: "0 30 * * *", target: "targets.a"})
        end.to raise_error(NATS::JetStream::Error::BadRequest) { |e| expect(e.err_code).to eql(10189) }
      end

      it "fails on a stream that does not allow schedules" do
        js.add_stream(name: "PLAIN", subjects: ["plain.>"])

        expect do
          js.publish("plain.a", "", schedule: {at: Time.now + 3600, target: "plain.b"})
        end.to raise_error(NATS::JetStream::Error::BadRequest) { |e| expect(e.err_code).to eql(10188) }
      end
    end

    describe "with the JetStream headers" do
      let(:nc) { NATS.connect(@s.uri) }
      let(:js) { nc.jetstream }

      after { nc.close }

      # The last message of a subject, or nil while there is none.
      def last_msg(stream, subject)
        js.get_last_msg(stream, subject)
      rescue NATS::JetStream::Error::NotFound
        nil
      end

      it "deduplicates and guards publishes" do
        js.add_stream(name: "GUARDED", subjects: ["guarded"])

        js.publish("guarded", "1", header: {NATS::JetStream::Header::MSG_ID => "one"})
        expect(js.publish("guarded", "1", header: {NATS::JetStream::Header::MSG_ID => "one"}).duplicate).to be(true)

        {
          NATS::JetStream::Header::EXPECTED_STREAM => ["OTHER", 10060],
          NATS::JetStream::Header::EXPECTED_LAST_SEQUENCE => ["5", 10071],
          NATS::JetStream::Header::EXPECTED_LAST_SUBJECT_SEQUENCE => ["5", 10071],
          NATS::JetStream::Header::EXPECTED_LAST_MSG_ID => ["two", 10070]
        }.each do |name, (value, err_code)|
          expect do
            js.publish("guarded", "2", header: {name => value})
          end.to raise_error(NATS::JetStream::Error::BadRequest) { |e| expect(e.err_code).to eql(err_code) }
        end

        ack = js.publish("guarded", "2", header: {
          NATS::JetStream::Header::EXPECTED_STREAM => "GUARDED",
          NATS::JetStream::Header::EXPECTED_LAST_SEQUENCE => "1",
          NATS::JetStream::Header::EXPECTED_LAST_SUBJECT_SEQUENCE => "1",
          NATS::JetStream::Header::EXPECTED_LAST_MSG_ID => "one"
        })
        expect(ack.seq).to eql(2)
      end

      it "guards a publish with the last sequence of another subject" do
        js.add_stream(name: "LOCKS", subjects: ["locks.>"])
        js.publish("locks.a", "a")
        header = {
          NATS::JetStream::Header::EXPECTED_LAST_SUBJECT_SEQUENCE => "1",
          NATS::JetStream::Header::EXPECTED_LAST_SUBJECT_SEQUENCE_SUBJECT => "locks.a"
        }

        expect(js.publish("locks.b", "b", header: header).seq).to eql(2)
        js.publish("locks.a", "a")
        expect do
          js.publish("locks.b", "b", header: header)
        end.to raise_error(NATS::JetStream::Error::BadRequest) { |e| expect(e.err_code).to eql(10071) }

        # The subject needs the sequence to check.
        expect do
          js.publish("locks.b", "b", header: header.slice(NATS::JetStream::Header::EXPECTED_LAST_SUBJECT_SEQUENCE_SUBJECT))
        end.to raise_error(NATS::JetStream::Error::BadRequest) { |e| expect(e.err_code).to eql(10193) }
      end

      it "leaves a marker when the last message of a subject expires" do
        js.add_stream(name: "MARKED", subjects: ["marked"],
          max_age: ::NATS::NANOSECONDS, subject_delete_marker_ttl: 50 * ::NATS::NANOSECONDS)
        js.publish("marked", "gone")

        marker = wait_until { last_msg("MARKED", "marked")&.then { |msg| msg if msg.headers } }
        expect(marker.headers).to include(
          NATS::JetStream::Header::MARKER_REASON => "MaxAge",
          NATS::JetStream::Header::MSG_TTL => "50s",
          NATS::JetStream::Header::ROLLUP => "sub"
        )
      end

      it "schedules a message" do
        js.add_stream(name: "SCHEDULES", subjects: ["schedules.>", "targets.>", "sources.>"],
          allow_msg_schedules: true, allow_msg_ttl: true)
        js.publish("sources.a", "sampled")

        # Due at once, so that it fires now.
        js.publish("schedules.a", "own", header: {
          NATS::JetStream::Header::SCHEDULE => "@at #{Time.now.utc.iso8601}",
          NATS::JetStream::Header::SCHEDULE_TARGET => "targets.a",
          NATS::JetStream::Header::SCHEDULE_SOURCE => "sources.a",
          NATS::JetStream::Header::SCHEDULE_TTL => "60",
          NATS::JetStream::Header::SCHEDULE_ROLLUP => "sub"
        })

        msg = wait_until { last_msg("SCHEDULES", "targets.a") }
        expect(msg.data).to eql("sampled")
        expect(msg.headers).to include(
          NATS::JetStream::Header::SCHEDULER => "schedules.a",
          NATS::JetStream::Header::SCHEDULE_NEXT => "purge",
          NATS::JetStream::Header::MSG_TTL => "60",
          NATS::JetStream::Header::ROLLUP => "sub"
        )
        # A schedule that fires once is removed.
        eventually { expect(last_msg("SCHEDULES", "schedules.a")).to be_nil }
      end

      it "schedules a message in a time zone" do
        js.add_stream(name: "SCHEDULES", subjects: ["schedules.>", "targets.>"], allow_msg_schedules: true)
        schedule = lambda do |zone|
          js.publish("schedules.a", "", header: {
            NATS::JetStream::Header::SCHEDULE => "0 0 9 * * *",
            NATS::JetStream::Header::SCHEDULE_TARGET => "targets.a",
            NATS::JetStream::Header::SCHEDULE_TIME_ZONE => zone
          })
        end

        seq = schedule.call("America/New_York").seq
        expect(js.get_msg("SCHEDULES", seq: seq).headers)
          .to include(NATS::JetStream::Header::SCHEDULE_TIME_ZONE => "America/New_York")
        expect { schedule.call("Mars/Olympus") }
          .to raise_error(NATS::JetStream::Error::BadRequest) { |e| expect(e.err_code).to eql(10223) }
      end

      it "cancels a schedule" do
        js.add_stream(name: "SCHEDULES", subjects: ["schedules.>", "targets.>"], allow_msg_schedules: true)
        ack = js.publish("schedules.a", "", header: {
          NATS::JetStream::Header::SCHEDULE => "@at #{(Time.now + 3600).utc.iso8601}",
          NATS::JetStream::Header::SCHEDULE_TARGET => "targets.a"
        })

        # Only if the schedule is still the one published.
        js.publish("schedules.cancel", "", header: {
          NATS::JetStream::Header::SCHEDULE_NEXT => "purge",
          NATS::JetStream::Header::SCHEDULER => "schedules.a",
          NATS::JetStream::Header::EXPECTED_LAST_SUBJECT_SEQUENCE => ack.seq.to_s,
          NATS::JetStream::Header::EXPECTED_LAST_SUBJECT_SEQUENCE_SUBJECT => "schedules.a"
        })

        expect(last_msg("SCHEDULES", "schedules.a")).to be_nil
      end

      it "tells where a message returned by a direct get was stored" do
        js.add_stream(name: "DIRECT", subjects: ["direct.>"], allow_direct: true)
        ack = js.publish("direct.a", "a")

        headers = js.get_msg("DIRECT", seq: ack.seq, direct: true).headers
        expect(headers).to include(
          NATS::JetStream::Header::STREAM => "DIRECT",
          NATS::JetStream::Header::SUBJECT => "direct.a",
          NATS::JetStream::Header::SEQUENCE => ack.seq.to_s
        )
        expect(Time.iso8601(headers[NATS::JetStream::Header::TIME_STAMP])).to be_within(60).of(Time.now)
      end

      it "tells where a republished message was stored, and the last one of its subject" do
        js.add_stream(name: "ORDERS", subjects: ["orders.>"], republish: {src: "orders.>", dest: "copies.>"})
        copies = nc.subscribe("copies.>")
        nc.flush

        js.publish("orders.a", "first")
        js.publish("orders.b", "other")
        js.publish("orders.a", "second")

        first, _, msg = 3.times.map { copies.next_msg(timeout: 5) }
        expect(first.header).to include(NATS::JetStream::Header::LAST_SEQUENCE => "0")
        expect(msg.data).to eql("second")
        expect(msg.header).to include(
          NATS::JetStream::Header::STREAM => "ORDERS",
          NATS::JetStream::Header::SUBJECT => "orders.a",
          NATS::JetStream::Header::SEQUENCE => "3",
          NATS::JetStream::Header::LAST_SEQUENCE => "1"
        )
      end

      it "tells which stream a sourced message came from" do
        js.add_stream(name: "ORIGIN", subjects: ["origin"])
        js.add_stream(name: "SOURCED", sources: [{name: "ORIGIN"}])

        js.publish("origin", "a")

        msg = wait_until { last_msg("SOURCED", "origin") }
        expect(msg.headers[NATS::JetStream::Header::STREAM_SOURCE]).to start_with("ORIGIN 1 ")
      end

      it "refuses batches that need a higher API level, but stores plain messages with it" do
        js.add_stream(name: "LEVELS", subjects: ["levels"], allow_atomic: true)
        level = {NATS::JetStream::Header::REQUIRED_API_LEVEL => "1000"}

        expect do
          js.publish("levels", "", header: level.merge(
            NATS::JetStream::Header::BATCH_ID => "b1",
            NATS::JetStream::Header::BATCH_SEQUENCE => "1",
            NATS::JetStream::Header::BATCH_COMMIT => "1"
          ))
        end.to raise_error(NATS::JetStream::API::Error) { |e| expect(e.err_code).to eql(10185) }
        ack = js.publish("levels", "plain", header: level)
        expect(js.get_msg("LEVELS", seq: ack.seq).headers).to include(level)
      end

      it "refuses API requests that need a higher API level" do
        js.add_stream(name: "LEVEL", subjects: ["level"])

        expect(js.stream_info("LEVEL", header: {NATS::JetStream::Header::REQUIRED_API_LEVEL => "1"}).config.name).to eql("LEVEL")
        expect do
          js.stream_info("LEVEL", header: {NATS::JetStream::Header::REQUIRED_API_LEVEL => "1000"})
        end.to raise_error(NATS::JetStream::API::Error) { |e|
          expect(e.code).to eql(412)
          expect(e.err_code).to eql(10185)
        }
      end
    end
  end

  describe "PubAck" do
    it "should ignore fields it does not know" do
      ack = NATS::JetStream::PubAck.new(JSON.parse('{"stream":"foo","seq":1,"future":true}', symbolize_names: true))
      expect(ack.stream).to eql("foo")
      expect(ack.seq).to eql(1)
    end

    it "should leave the hash it is given unchanged" do
      fields = {stream: "foo", seq: 1, future: true}.freeze

      expect(NATS::JetStream::PubAck.new(fields).seq).to eql(1)
      expect(fields).to eql({stream: "foo", seq: 1, future: true})
    end
  end

  describe "Pull Subscribe" do
    before do
      @tmpdir = Dir.mktmpdir("ruby-jetstream")
      @s = NatsServerControl.new("nats://127.0.0.1:4524", "/tmp/test-nats.pid", "-js -sd=#{@tmpdir}")
      @s.start_server(true)
    end

    after do
      @s.kill_server
      FileUtils.remove_entry(@tmpdir)
    end

    before do
      nc = NATS.connect(@s.uri)
      stream_req = {
        name: "test",
        subjects: ["test"]
      }
      resp = nc.request("$JS.API.STREAM.CREATE.test", stream_req.to_json)
      expect(resp).to_not be_nil
      nc.close
    end

    after do
      nc = NATS.connect(@s.uri)
      stream_req = {
        name: "test",
        subjects: ["test"]
      }
      resp = nc.request("$JS.API.STREAM.DELETE.test", stream_req.to_json)
      expect(resp).to_not be_nil
      nc.close
    end

    let(:nc) { NATS.connect(@s.uri) }

    it "should auto create pull subscription" do
      js = nc.jetstream
      js.add_stream(name: "hello", subjects: ["hello", "world", "hello.>"])

      js.publish("hello", "1")
      js.publish("world", "2")
      js.publish("hello.world", "3")

      sub = js.pull_subscribe("hello", "psub", config: {max_waiting: 30})
      info = sub.consumer_info
      expect(info.config.max_waiting).to eql(30)
      expect(info.num_pending).to eql(1)

      # Only one message matches; a larger batch would wait out the timeout.
      msgs = sub.fetch(1)
      msgs.each do |msg|
        msg.ack
      end

      # Using the API type.
      # TODO: Handle mismatch between config and current state.
      config = NATS::JetStream::API::ConsumerConfig.new(max_waiting: 128)
      sub = js.pull_subscribe("hello", "psub2", config: config)
      info = sub.consumer_info
      expect(info.config.max_waiting).to eql(128)
      expect(info.num_pending).to eql(1)

      msgs = sub.fetch(1)
      msgs.each do |msg|
        msg.ack_sync
      end
      info = sub.consumer_info
      expect(info.num_pending).to eql(0)
    end

    it "should pull subscribe with ack_policy none" do
      js = nc.jetstream
      js.publish("test", "1")

      # The server omits ack_wait from consumers that do not ack.
      sub = js.pull_subscribe("test", "psub-none", config: {ack_policy: "none"})
      msgs = sub.fetch(1)
      expect(msgs.map(&:data)).to eql(["1"])
      info = sub.consumer_info
      expect(info.config.ack_policy).to eql("none")
      expect(info.config.ack_wait).to be_nil
      expect(info.num_ack_pending).to eql(0)

      # Binding to the existing consumer looks it up first.
      js.publish("test", "2")
      sub = js.pull_subscribe("test", "psub-none")
      msgs = sub.fetch(1)
      expect(msgs.map(&:data)).to eql(["2"])
    end

    it "should find the pull subscription by subject" do
      nc = NATS.connect(@s.uri)
      js = nc.jetstream

      consumer_req = {
        stream_name: "test",
        config: {
          durable_name: "test-find",
          ack_policy: "explicit",
          max_ack_pending: 20,
          max_waiting: 3,
          ack_wait: 5 * 1_000_000_000 # 5 seconds
        }
      }
      resp = nc.request("$JS.API.CONSUMER.DURABLE.CREATE.test.test-find", consumer_req.to_json)
      expect(resp).to_not be_nil

      sub = js.pull_subscribe("test", "test-find")
      expect(sub.sid).to eql(2)
      sub.unsubscribe
    end

    it "should pull subscribe and fetch messages" do
      nc = NATS.connect(@s.uri)
      js = nc.jetstream

      consumer_req = {
        stream_name: "test",
        config: {
          durable_name: "test",
          ack_policy: "explicit",
          max_ack_pending: 20,
          max_waiting: 3,
          ack_wait: 5 * 1_000_000_000 # 5 seconds
        }
      }
      resp = nc.request("$JS.API.CONSUMER.DURABLE.CREATE.test.test", consumer_req.to_json)
      expect(resp).to_not be_nil

      # Send 10 messages...
      1.upto(10) { |n| js.publish("test", "hello: #{n}") }

      sub = js.pull_subscribe("test", "test", stream: "test")

      # Fetch 1, leave 9 pending.
      msgs = sub.fetch(1)
      msgs.each do |msg|
        msg.ack
      end
      msg = msgs.first
      expect(msg.data).to eql("hello: 1")

      meta = msg.metadata
      expect(meta.sequence.stream).to eql(1)
      expect(meta.sequence.consumer).to eql(1)
      expect(meta.domain).to eql("")
      expect(meta.num_delivered).to eql(1)
      expect(meta.num_pending).to eql(9)
      expect(meta.stream).to eql("test")
      expect(meta.consumer).to eql("test")

      # Check again that the parsing is memoized.
      meta = msg.metadata
      expect(meta.sequence.stream).to eql(1)
      expect(meta.sequence.consumer).to eql(1)

      # Confirm the metadata.o
      time_since = Time.now - meta.timestamp
      expect(time_since).to be_between(0, 1)

      # Confirm that cannot double ack a message.
      [:ack, :ack_sync, :nak, :term].each do |method_sym|
        expect do
          msg.send(method_sym)
        end.to raise_error(NATS::JetStream::Error::MsgAlreadyAckd)
      end

      # This one is ok to ack multiple times.
      msg.in_progress

      # Fetch 1 more, should be 8 pending now.
      msgs = sub.fetch(1)
      msg = msgs.first
      msg.ack
      expect(msg.data).to eql("hello: 2")
      wait_until(description: "the ack to be processed") { sub.consumer_info.num_ack_pending == 0 }

      resp = nc.request("$JS.API.CONSUMER.INFO.test.test", timeout: 2)
      info = JSON.parse(resp.data, symbolize_names: true)
      expect(info).to include({
        num_waiting: 0,
        num_ack_pending: 0,
        num_pending: 8
      })
      expect(info[:delivered]).to include({
        consumer_seq: 2,
        stream_seq: 2
      })
      expect(info[:delivered][:consumer_seq]).to eql(2)
      expect(info[:delivered][:stream_seq]).to eql(2)

      # Fetch all the 8 pending messages.
      msgs = sub.fetch(8, timeout: 1)
      expect(msgs.count).to eql(8)

      i = 3
      msgs.each do |msg|
        expect(msg.data).to eql("hello: #{i}")
        msg.ack
        i += 1
      end

      # Pull Subscribe only works with #fetch
      expect do
        sub.next_msg
      end.to raise_error(NATS::JetStream::Error)

      # Invalid fetch sizes are errors.
      expect do
        sub.fetch(-1)
      end.to raise_error(NATS::JetStream::Error)

      expect do
        sub.fetch(0)
      end.to raise_error(NATS::JetStream::Error)

      # Nothing pending.
      resp = nc.request("$JS.API.CONSUMER.INFO.test.test", timeout: 2)
      info = JSON.parse(resp.data, symbolize_names: true)
      expect(info[:delivered]).to include({
        consumer_seq: 10,
        stream_seq: 10
      })
      expect(sub.pending_queue.size).to eql(0)

      # Publish 5 more messages.
      11.upto(15) { |n| js.publish("test", "hello: #{n}") }
      nc.flush

      resp = nc.request("$JS.API.CONSUMER.INFO.test.test", timeout: 2)
      info = JSON.parse(resp.data, symbolize_names: true)
      expect(info[:delivered]).to include({
        consumer_seq: 10,
        stream_seq: 10
      })

      # Only 5 messages will be received, with 2 pending though won't be delivered yet.
      # This should take as long as the timeout but should not throw an exception since
      # the client at least received a few messagers.
      msgs = sub.fetch(7, timeout: 2)
      expect(msgs.count).to eql(5)
      expect(sub.pending_queue.size).to eql(0)

      i = 11
      msgs.each do |msg|
        expect(msg.data).to eql("hello: #{i}")
        msg.ack
        i += 1
      end

      resp = nc.request("$JS.API.CONSUMER.INFO.test.test", timeout: 2)
      info = JSON.parse(resp.data, symbolize_names: true)
      expect(info[:delivered]).to include({
        consumer_seq: 15,
        stream_seq: 15
      })

      # 10 more messages
      16.upto(25) { |n| js.publish("test", "hello: #{n}") }
      nc.flush

      # No new messages delivered yet...
      sleep 0.5
      expect(sub.pending_queue.size).to eql(0)

      resp = nc.request("$JS.API.CONSUMER.INFO.test.test", timeout: 2)
      info = JSON.parse(resp.data, symbolize_names: true)
      expect(info[:delivered]).to include({
        consumer_seq: 15,
        stream_seq: 15
      })

      # Get 10 messages which are the total (25).
      msgs = sub.fetch(10)
      i = 16
      msgs.each do |msg|
        expect(msg.data).to eql("hello: #{i}")
        msg.ack
        i += 1
      end
      expect(msgs.count).to eql(10)
      nc.flush

      # Should have not been no more messages!
      expect do
        sub.fetch(1, timeout: 1)
      end.to raise_error(NATS::IO::Timeout)

      resp = nc.request("$JS.API.CONSUMER.INFO.test.test", timeout: 2)
      info = JSON.parse(resp.data, symbolize_names: true)
      expect(info).to include({
        num_waiting: 0,
        num_ack_pending: 0,
        num_pending: 0
      })
      expect(info[:delivered]).to include({
        consumer_seq: 25,
        stream_seq: 25
      })
      # expect(sub.pending_queue.size).to eql(0)
      expect(i).to eql(26)

      # There should be no more messages.
      expect do
        sub.fetch(10, timeout: 1)
      end.to raise_error(NATS::IO::Timeout)

      # Requests that have timed out so far will linger.
      resp = nc.request("$JS.API.CONSUMER.INFO.test.test", timeout: 2)
      info = JSON.parse(resp.data, symbolize_names: true)
      expect(info).to include({
        num_waiting: 0,
        num_ack_pending: 0,
        num_pending: 0
      })
      expect(info[:delivered]).to include({
        consumer_seq: 25,
        stream_seq: 25
      })

      # Make a lot of requests to get a request timeout error.
      ts = []
      errors = []
      3.times do
        ts << Thread.new do
          msgs = sub.fetch(2, timeout: 0.2)
        rescue => e
          errors << e
        end
      end
      ts.each { |t| t.join }

      expect(errors.count > 0).to eql(true)
      e = errors.first
      expect(e).to be_a(NATS::IO::Timeout)

      # NOTE: After +2.7.1 info also resets the expired requests.
      #
      # resp = nc.request("$JS.API.CONSUMER.INFO.test.test", timeout: 2)
      # info = JSON.parse(resp.data, symbolize_names: true)
      # expect(info[:num_waiting]).to be_between(1, 3)
      #

      # This should not cause 408 timeout errors.
      10.times do
        expect do
          sub.fetch(1, timeout: 0.5)
        end.to raise_error(NATS::IO::Timeout)
        # resp = nc.request("$JS.API.CONSUMER.INFO.test.test", timeout: 2)
        # info = JSON.parse(resp.data, symbolize_names: true)
        # expect(info[:num_waiting]).to be_between(1, 3)
      end

      # Force request timeout errors.
      ts = []
      5.times do
        ts << Thread.new do
          msgs = sub.fetch(1, timeout: 0.5)
          expect(msgs).to be_empty
        rescue => e
          errors << e
        end
      end
      ts.each do |t|
        t.join
      end
      api_err = errors.select { |o| o.is_a?(NATS::Timeout) }
      expect(api_err).to_not be_empty
      # expect(api_err.first.code).to eql("408")

      nc.close
    end

    it "should unsubscribe" do
      nc = NATS.connect(@s.uri)
      js = nc.jetstream

      consumer_req = {
        stream_name: "test",
        config: {
          durable_name: "delsub",
          ack_policy: "explicit",
          max_ack_pending: 20,
          max_waiting: 3,
          ack_wait: 5 * 1_000_000_000 # 5 seconds
        }
      }
      resp = nc.request("$JS.API.CONSUMER.DURABLE.CREATE.test.delsub", consumer_req.to_json)
      expect(resp).to_not be_nil

      sub = js.pull_subscribe("test", "delsub", stream: "test")

      expect do
        sub.fetch(1, timeout: 0.5)
      end.to raise_error(NATS::IO::Timeout)

      ack = js.publish("test", "hello")
      expect(ack.seq).to eql(1)
      msgs = sub.fetch
      expect(msgs.size).to eql(1)

      ack = js.publish("test", "hello")
      expect(ack.seq).to eql(2)

      sub.unsubscribe

      expect do
        msgs = sub.fetch(1, timeout: 0.5)
      end.to raise_error(NATS::Timeout)

      expect do
        sub.unsubscribe
      end.to raise_error(NATS::IO::BadSubscription)
    end

    # TODO: What do we test here?
    it "should account pending data" do
      nc = NATS.connect(@s.uri)
      nc2 = NATS.connect(@s.uri)
      js = nc.jetstream
      subject = "limits.test"

      nc.on_error do |e|
        puts e
      end

      js.add_stream(name: "limitstest", subjects: [subject])

      begin
        # Continuously send messages until reaching pending bytes limit.
        t = Thread.new do
          payload = "A" * 1024
          loop do
            nc2.publish(subject, payload)
            sleep 0.01
          end
        end

        sub = js.pull_subscribe(subject, "test")
        65.times do |i|
          msgs = sub.fetch(1)
          msgs.each do |msg|
            msg.ack
          end
        end

        sub = js.pull_subscribe(subject, "test")
        65.times do |i|
          msgs = sub.fetch(2)
          msgs.each do |msg|
            msg.ack
          end
        end
      ensure
        nc.close
        nc2.close
        t.exit
      end
    end

    it "should create and bind to consumer with name" do
      nc = NATS.connect(@s.uri)
      js = nc.jetstream

      js.add_stream(name: "ctests", subjects: ["a", "b", "c.>"])
      js.publish("a", "hello world!")
      js.publish("b", "hello world!!")
      js.publish("c.d", "hello world!!!")
      js.publish("c.d.e", "hello world!!!!")

      tsub = nc.subscribe("$JS.API.CONSUMER.>")

      # ephemeral consumer
      consumer_name = "ephemeral"
      cinfo = js.add_consumer("ctests", name: consumer_name, ack_policy: "explicit")
      expect(cinfo.config.name).to eql(consumer_name)

      msg = tsub.next_msg
      expect(msg.subject).to eql("$JS.API.CONSUMER.CREATE.ctests.ephemeral")

      sub = js.pull_subscribe("", "", stream: "ctests", consumer: "ephemeral")
      cinfo = sub.consumer_info
      expect(cinfo.config.name).to eql(consumer_name)
      msgs = sub.fetch(1)
      expect(msgs.first.data).to eql("hello world!")
      msgs.first.ack_sync
      msg = tsub.next_msg
      expect(msg.subject).to eql("$JS.API.CONSUMER.INFO.ctests.ephemeral")
      tsub.unsubscribe

      # Create durable pull consumer with a name.
      tsub = nc.subscribe("$JS.API.CONSUMER.>")
      consumer_name = "durable"
      cinfo = js.add_consumer("ctests",
        name: consumer_name,
        durable_name: consumer_name,
        ack_policy: "explicit")
      expect(cinfo.config.name).to eql(consumer_name)
      msg = tsub.next_msg
      expect(msg.subject).to eql("$JS.API.CONSUMER.CREATE.ctests.durable")
      sub = js.pull_subscribe("", "durable", stream: "ctests")
      cinfo = sub.consumer_info
      expect(cinfo.config.name).to eql(consumer_name)
      msgs = sub.fetch(1)
      expect(msgs.first.data).to eql("hello world!")
      msgs.first.ack_sync
      msg = tsub.next_msg
      expect(msg.subject).to eql("$JS.API.CONSUMER.INFO.ctests.durable")
      tsub.unsubscribe

      # Create durable pull consumer with a name and a filter_subject
      tsub = nc.subscribe("$JS.API.CONSUMER.>")
      consumer_name = "durable2"
      cinfo = js.add_consumer("ctests",
        name: consumer_name,
        durable_name: consumer_name,
        filter_subject: "b",
        ack_policy: "explicit")
      expect(cinfo.config.name).to eql(consumer_name)
      msg = tsub.next_msg
      expect(msg.subject).to eql("$JS.API.CONSUMER.CREATE.ctests.durable2.b")
      sub = js.pull_subscribe("", "durable2", stream: "ctests")
      msgs = sub.fetch(1)
      expect(msgs.first.data).to eql("hello world!!")
      msgs.first.ack_sync
      tsub.unsubscribe

      # Create durable pull consumer with a name and a filter_subject
      tsub = nc.subscribe("$JS.API.CONSUMER.>")
      consumer_name = "durable3"
      cinfo = js.add_consumer("ctests",
        name: consumer_name,
        durable_name: consumer_name,
        filter_subject: ">",
        ack_policy: "explicit")
      expect(cinfo.config.name).to eql(consumer_name)
      msg = tsub.next_msg
      expect(msg.subject).to eql("$JS.API.CONSUMER.CREATE.ctests.durable3")
      sub = js.pull_subscribe("", "durable3", stream: "ctests")
      msgs = sub.fetch(1)
      expect(msgs.first.data).to eql("hello world!")
      msgs.first.ack_sync
      tsub.unsubscribe

      # name and durable must match if both present.
      expect do
        js.add_consumer("ctests",
          name: "foo",
          durable_name: "bar",
          ack_policy: "explicit")
      end.to raise_error NATS::JetStream::Error::BadRequest
      begin
        js.add_consumer("ctests",
          name: "foo",
          durable_name: "bar",
          ack_policy: "explicit")
      rescue => e
        expect(e.description).to eql(%(consumer name in subject does not match durable name in request))
      end

      # consumer name and inactive
      consumer_name = "inactive"
      cinfo = js.add_consumer("ctests",
        name: consumer_name,
        durable_name: consumer_name,
        inactive_threshold: 2, # seconds
        ack_policy: "explicit",
        mem_storage: true)
      expect(cinfo.config.inactive_threshold).to eql(2)
      expect(cinfo.config.mem_storage).to eql(true)
    end
  end

  describe "Push Subscribe" do
    before do
      @tmpdir = Dir.mktmpdir("ruby-jetstream")
      @s = NatsServerControl.new("nats://127.0.0.1:4527", "/tmp/test-nats.pid", "-js -sd=#{@tmpdir}")
      @s.start_server(true)
    end

    after do
      @s.kill_server
      FileUtils.remove_entry(@tmpdir)
    end

    before do
      nc = NATS.connect(@s.uri)
      stream_req = {
        name: "test",
        subjects: ["test"]
      }
      resp = nc.request("$JS.API.STREAM.CREATE.test", stream_req.to_json)
      expect(resp).to_not be_nil
      nc.close
    end

    after do
      nc = NATS.connect(@s.uri)
      stream_req = {
        name: "test",
        subjects: ["test"]
      }
      resp = nc.request("$JS.API.STREAM.DELETE.test", stream_req.to_json)
      expect(resp).to_not be_nil
      nc.close
    end

    let(:nc) { NATS.connect(@s.uri) }

    it "should create ephemeral subscription with auto and manual ack" do
      js = nc.jetstream
      js.add_stream(name: "hello", subjects: ["hello", "world", "hello.>"])

      js.publish("hello", "1")
      js.publish("world", "2")
      js.publish("hello.world", "3")
      js.publish("hello", "2")

      # Auto Ack
      future = Future.new
      msgs = []
      sub = js.subscribe("hello.world") do |msg|
        # They will be auto acked
        msgs << msg
        future.set_result(msgs)
      end
      msgs = future.wait_for(1)
      expect(msgs.count).to eql(1)

      sleep 0.5
      info = sub.consumer_info
      expect(info.stream_name).to eql("hello")
      expect(info.num_pending).to eql(0)
      expect(info.num_ack_pending).to eql(0)

      # Attempting to ack again is an error.
      expect do
        msgs[0].ack
      end.to raise_error(NATS::JetStream::Error::MsgAlreadyAckd)

      # Manual Ack
      future = Future.new
      msgs = []
      sub = js.subscribe("hello", manual_ack: true) do |msg|
        msgs << msg
        future.set_result(msgs) if msgs.count == 2
      end
      msgs = future.wait_for(1)
      expect(msgs.count).to eql(2)
      expect(msgs[0].data).to eql("1")
      expect(msgs[1].data).to eql("2")

      info = sub.consumer_info
      expect(info.stream_name).to eql("hello")
      expect(info.num_pending).to eql(0)
      expect(info.num_ack_pending).to eql(2)
      msgs.each { |msg| msg.ack_sync }
      sleep 1

      info = sub.consumer_info
      expect(info.num_ack_pending).to eql(0)
      sub.unsubscribe

      # Without callback
      sub = js.subscribe("hello")
      msg = sub.next_msg
      msg.ack_sync
      info = sub.consumer_info
      expect(info.stream_name).to eql("hello")
      expect(info.num_pending).to eql(0)
      expect(info.num_ack_pending).to eql(1)
      sub.unsubscribe
    end

    it "should create durable single subscribers" do
      js = nc.jetstream
      js.add_stream(name: "hello", subjects: ["hello", "world", "hello.>"])

      js.publish("hello", "1")
      js.publish("world", "2")
      js.publish("hello.world", "3")
      js.publish("hello", "2")

      # Cannot have queue and durable be different.
      expect do
        js.subscribe("hello", queue: "foo", durable: "hello")
      end.to raise_error(NATS::JetStream::Error)

      # Async susbcriber
      future = Future.new
      msgs = []
      sub = js.subscribe("hello", durable: "first", manual_ack: true) do |msg|
        msgs << msg
        future.set_result(msgs) if msgs.count == 2
      end
      msgs = future.wait_for(1)
      expect(msgs.count).to eql(2)

      # Resubscribing should fail since already push bound
      expect do
        js.subscribe("hello", durable: "first")
      end.to raise_error(NATS::JetStream::Error)

      info = sub.consumer_info
      expect(info.num_ack_pending).to eql(2)
      sub.unsubscribe

      # Trigger a redelivery of the messages.
      msgs.each do |msg|
        msg.nak
      end

      info = sub.consumer_info
      expect(info.num_pending).to eql(0)
      expect(info.num_ack_pending).to eql(2)

      # Sync subscribe to get the same messages again.
      sub = js.subscribe("hello", durable: "first")
      msg = sub.next_msg
      msg.ack_sync

      info = sub.consumer_info
      expect(info.num_pending).to eql(0)
      expect(info.num_ack_pending).to eql(1)
    end

    it "should create subscriber with a queue" do
      js = nc.jetstream

      # Cannot have queue and durable be different.
      qsubs = []
      5.times do
        qsub = js.subscribe("test", queue: "foo", manual_ack: true)
        qsubs << qsub
      end

      50.times do |i|
        js.publish("test", i.to_s)
      end

      # Each should get at least a couple of messages
      qsubs.each do |qsub|
        expect(qsub.pending_queue.size).to be >= 2
      end
    end

    it "should create subscribers with custom config" do
      js = nc.jetstream
      js.add_stream(name: "custom", subjects: ["custom"])

      1.upto(10).each do |i|
        js.publish("custom", "n:#{i}")
      end

      sub = js.subscribe("custom", durable: "example", config: {deliver_policy: "new"})

      js.publish("custom", "last")
      msg = sub.next_msg

      expect(msg.data).to eql("last")
      expect(msg.metadata.sequence.stream).to_not eql(1)
      expect(msg.metadata.sequence.consumer).to eql(1)

      cinfo = js.consumer_info("custom", "example")
      expect(cinfo.config[:deliver_policy]).to eql("new")

      nc.close
    end

    it "should create subscribers with ack_policy none" do
      js = nc.jetstream
      js.add_stream(name: "none", subjects: ["none"])
      js.publish("none", "1")

      # The server omits ack_wait from consumers that do not ack.
      sub = js.subscribe("none", config: {ack_policy: "none"})
      expect(sub.next_msg.data).to eql("1")
      info = sub.consumer_info
      expect(info.config.ack_policy).to eql("none")
      expect(info.config.ack_wait).to be_nil
      sub.unsubscribe

      sub = js.subscribe("none", durable: "none-dur", config: {ack_policy: "none"})
      expect(sub.next_msg.data).to eql("1")
      sub.unsubscribe
      wait_until { !js.consumer_info("none", "none-dur").push_bound }

      # Binding to the existing durable looks it up first.
      sub = js.subscribe("none", durable: "none-dur")
      js.publish("none", "2")
      expect(sub.next_msg.data).to eql("2")
    end
  end

  describe "Domain" do
    before do
      @tmpdir = Dir.mktmpdir("ruby-jetstream-domain")
      config_opts = {
        "pid_file" => "/tmp/nats_js_domain_1.pid",
        "host" => "127.0.0.1",
        "port" => 4729
      }
      @domain = "estre"
      @s = NatsServerControl.init_with_config_from_string(%(
        port = #{config_opts["port"]}
        jetstream {
          domain = #{@domain}
          store_dir = "#{@tmpdir}"
        }
      ), config_opts)
      @s.start_server(true)
    end

    after do
      @s.kill_server
      FileUtils.remove_entry(@tmpdir)
    end

    it "should produce, consume and ack messages in a stream" do
      nc = NATS.connect(@s.uri)

      # Create stream in the domain.
      subject = "foo"
      stream_name = "test"
      stream_req = {
        name: stream_name,
        subjects: [subject]
      }
      resp = nc.request("$JS.#{@domain}.API.STREAM.CREATE.#{stream_name}",
        stream_req.to_json)
      expect(resp).to_not be_nil

      # Now create a consumer in the domain.
      durable_name = "test"
      consumer_req = {
        stream_name: stream_name,
        config: {
          durable_name: "test",
          ack_policy: "explicit",
          max_ack_pending: 20,
          max_waiting: 3,
          ack_wait: 5 * 1_000_000_000 # 5 seconds
        }
      }
      resp = nc.request("$JS.#{@domain}.API.CONSUMER.DURABLE.CREATE.#{stream_name}.#{durable_name}",
        consumer_req.to_json)
      expect(resp).to_not be_nil

      # Create producer with custom domain.
      producer = nc.JetStream(domain: @domain)
      ack = producer.publish(subject)
      expect(ack[:stream]).to eql(stream_name)
      expect(ack[:domain]).to eql(@domain)
      expect(ack[:seq]).to eql(1)

      # Without domain would work as well in this case.
      js = nc.JetStream()
      ack = js.publish(subject)
      expect(ack[:stream]).to eql(stream_name)
      expect(ack[:domain]).to eql(@domain)
      expect(ack[:seq]).to eql(2)

      # Connecting to wrong domain should fail.
      js = nc.JetStream(domain: "stok")
      expect do
        js.pull_subscribe(subject, durable_name, stream: stream_name)
      end.to raise_error(NATS::JetStream::Error::ServiceUnavailable)

      # Check pending acks before fetching.
      resp = nc.request("$JS.#{@domain}.API.CONSUMER.INFO.#{stream_name}.#{durable_name}")
      info = JSON.parse(resp.data, symbolize_names: true)
      expect(info[:num_pending]).to eql(2)

      js = nc.JetStream(domain: @domain)
      sub = js.pull_subscribe(subject, durable_name, stream: stream_name)
      msgs = sub.fetch(1)
      msg = msgs.first
      msg.ack_sync

      # Confirm ack went through.
      resp = nc.request("$JS.#{@domain}.API.CONSUMER.INFO.#{stream_name}.#{durable_name}")
      info = JSON.parse(resp.data, symbolize_names: true)
      expect(info[:num_pending]).to eql(1)

      js = nc.jetstream(domain: "estre")
      info = js.account_info

      # v2.11 starts to include API levels, and the level grows with
      # every server release, so don't pin it.
      api_hash = a_hash_including({total: 5, errors: 0})

      expected = a_hash_including({
        type: "io.nats.jetstream.api.v1.account_info_response",
        memory: 0,
        storage: 66,
        streams: 1,
        consumers: 1,
        limits: a_hash_including({
          max_memory: -1,
          max_storage: -1,
          max_streams: -1,
          max_consumers: -1,
          max_ack_pending: -1,
          memory_max_stream_bytes: -1,
          storage_max_stream_bytes: -1,
          max_bytes_required: false
        }),
        domain: "estre",
        api: api_hash
      })

      # Filter these out
      info.delete(:reserved_memory) if info[:reserved_memory]
      info.delete(:reserved_storage) if info[:reserved_storage]

      expect(info).to match(expected)
    end

    it "should nack messages with a delay" do
      nc = NATS.connect(@s.uri)

      # Create stream in the domain.
      subject = "foo"
      stream_name = "test"
      stream_req = {
        name: stream_name,
        subjects: [subject]
      }
      resp = nc.jsm(domain: @domain).add_stream(stream_req)
      expect(resp).to_not be_nil

      # Now create a consumer in the domain.
      durable_name = "test"
      consumer_req = {
        stream_name: stream_name,
        config: {
          durable_name: "test",
          ack_policy: "explicit",
          max_ack_pending: 20,
          max_waiting: 3,
          ack_wait: 5 # seconds
        }
      }
      resp = nc.jsm(domain: @domain).add_consumer(stream_name, consumer_req[:config])
      expect(resp).to_not be_nil

      # Create producer with custom domain.
      producer = nc.JetStream(domain: @domain)
      ack = producer.publish(subject)
      expect(ack[:stream]).to eql(stream_name)
      expect(ack[:domain]).to eql(@domain)
      expect(ack[:seq]).to eql(1)

      # Pull subscriber
      js = nc.JetStream(domain: @domain)
      sub = js.pull_subscribe(subject, durable_name, stream: stream_name)
      msgs = sub.fetch(1)
      msg = msgs.first
      msg.nak(delay: 2)

      expect do
        msg.nak(delay: 2, timeout: 2)
      end.to raise_error(NATS::JetStream::Error::MsgAlreadyAckd)

      msgs = sub.fetch(1)
      msg = msgs.first
      resp = msg.nak(delay: 2, timeout: 2)
      expect(resp).to be_a(NATS::Msg)

      msgs = sub.fetch(1)
      msg = msgs.first
      msg.nak

      msgs = sub.fetch(1)
      msg = msgs.first
      expect(msg.nak(timeout: 2)).to be_a(NATS::Msg)
    end

    it "should bail when stream or consumer does not exist in domain" do
      nc = NATS.connect(@s.uri)
      js = nc.JetStream(domain: @domain)

      # Should try to auto lookup and fail.
      expect do
        js.pull_subscribe("foo", "bar")
      end.to raise_error(NATS::JetStream::Error::NotFound)

      # Invalid stream name.
      expect do
        js.pull_subscribe("foo", "bar", stream: "")
      end.to raise_error(NATS::JetStream::Error::InvalidStreamName)

      # Stream that does not exist.
      expect do
        js.pull_subscribe("foo", "bar", stream: "nonexistent")
      end.to raise_error(NATS::JetStream::Error::StreamNotFound)

      # Now create the stream.
      stream_req = {
        name: "foo",
        subjects: ["foo"]
      }
      resp = nc.request("$JS.#{@domain}.API.STREAM.CREATE.foo", stream_req.to_json)
      expect(resp).to_not be_nil

      # Should find the stream now but fail to find the consumer.
      expect do
        js.pull_subscribe("foo", "bar", stream: "foo")
      end.to raise_error(NATS::JetStream::Error::ConsumerNotFound)

      consumer_req = {
        stream_name: "foo",
        config: {
          durable_name: "test-find",
          ack_policy: "explicit",
          max_ack_pending: 20,
          max_waiting: 3,
          ack_wait: 5 * 1_000_000_000 # 5 seconds
        }
      }
      resp = nc.request("$JS.API.CONSUMER.DURABLE.CREATE.foo.test-find", consumer_req.to_json)
      expect(resp).to_not be_nil

      # FIXME: This should return a not found error instead of empty response.
      # {:type=>"io.nats.jetstream.api.v1.stream_names_response", :total=>0, :offset=>0, :limit=>1024, :streams=>nil}
      # sub = js.pull_subscribe("missing", "bar")
      js.pull_subscribe("foo", "test-find")
    end
  end

  describe "Errors" do
    it "NATS::Error" do
      expect do
        raise NATS::IO::Timeout
      end.to raise_error(NATS::Error)

      expect do
        raise NATS::IO::SocketTimeoutError
      end.to raise_error(NATS::Error)

      expect do
        raise NATS::IO::SocketTimeoutError
      end.to raise_error(NATS::Timeout)
    end

    it "JetStream::Error" do
      # NATS::Error can catch either JetStream or NATS errors.
      expect do
        raise NATS::JetStream::Error
      end.to raise_error(NATS::Error)

      expect do
        raise NATS::IO::Error
      end.to raise_error(NATS::Error)

      expect do
        raise NATS::IO::Timeout
      end.to raise_error(NATS::Error)

      expect do
        raise NATS::Timeout
      end.to raise_error(NATS::Error)
    end

    it "JetStream::API::Error" do
      expect do
        raise NATS::JetStream::Error::ConsumerNotFound
      end.to raise_error(NATS::JetStream::API::Error)

      expect do
        raise NATS::JetStream::Error::ConsumerNotFound
      end.to raise_error(NATS::Error)

      expect do
        raise NATS::JetStream::Error::StreamNotFound
      end.to raise_error(NATS::JetStream::API::Error)

      expect do
        raise NATS::JetStream::Error::StreamNotFound
      end.to raise_error(NATS::Error)

      expect do
        raise NATS::JetStream::Error::ConsumerNotFound
      end.to raise_error(NATS::JetStream::Error::NotFound)

      expect do
        raise NATS::JetStream::Error::ServiceUnavailable
      end.to raise_error(NATS::JetStream::Error)

      expect do
        raise NATS::JetStream::Error::ServiceUnavailable
      end.to raise_error(NATS::JetStream::API::Error)

      expect do
        raise NATS::JetStream::Error::ServiceUnavailable
      end.to raise_error(NATS::Error)

      expect do
        raise NATS::JetStream::Error::ServiceUnavailable
      end.to raise_error(an_instance_of(NATS::JetStream::Error::ServiceUnavailable)
                           .and(having_attributes(code: 503)))

      expect do
        raise NATS::JetStream::Error::NotFound
      end.to raise_error(an_instance_of(NATS::JetStream::Error::NotFound)
                           .and(having_attributes(code: 404)))

      expect do
        raise NATS::JetStream::Error::BadRequest
      end.to raise_error(an_instance_of(NATS::JetStream::Error::BadRequest)
                           .and(having_attributes(code: 400)))
    end
  end

  describe "JSM" do
    before do
      @tmpdir = Dir.mktmpdir("ruby-jsm")
      config_opts = {
        "pid_file" => "/tmp/nats_jsm_1.pid",
        "host" => "127.0.0.1",
        "port" => 4730
      }
      @domain = "estre"
      @s = NatsServerControl.init_with_config_from_string(%(
        port = #{config_opts["port"]}
        jetstream {
          domain = #{@domain}
          store_dir = "#{@tmpdir}"
        }
      ), config_opts)
      @s.start_server(true)
    end

    after do
      @s.kill_server
      FileUtils.remove_entry(@tmpdir)
    end

    let(:nc) { NATS.connect(@s.uri) }

    it "should support jsm.add_stream" do
      stream_config = {
        name: "mystream"
      }
      resp = nc.jsm.add_stream(stream_config)
      expect(resp).to be_a NATS::JetStream::API::StreamCreateResponse
      expect(resp.type).to eql("io.nats.jetstream.api.v1.stream_create_response")
      expect(resp.config.name).to eql("mystream")
      expect(resp.config.num_replicas).to eql(1)

      resp = nc.jsm.add_stream(name: "stream2")
      expect(resp).to be_a NATS::JetStream::API::StreamCreateResponse
      expect(resp.config.name).to eql("stream2")
      expect(resp.config.num_replicas).to eql(1)

      # Can also use the types for the request.
      stream_config = {
        name: "stream3"
      }
      config = NATS::JetStream::API::StreamConfig.new(stream_config)
      resp = nc.jsm.add_stream(config)
      expect(resp).to be_a NATS::JetStream::API::StreamCreateResponse
      expect(resp.config.name).to eql("stream3")
      expect(resp.config.num_replicas).to eql(1)

      expect do
        nc.jsm.add_stream(foo: "foo")
      end.to raise_error(ArgumentError)

      expect do
        nc.jsm.add_stream(foo: "foo.*")
      end.to raise_error(ArgumentError)

      # Raise when stream names contain prohibited characters
      expect do
        nc.jsm.add_stream(name: "foo.bar*baz")
      end.to raise_error(ArgumentError)

      placement = {cluster: "foo", tags: ["a"]}
      resp = nc.jsm.add_stream(name: "v29",
        subjects: ["v29"],
        num_replicas: 1,
        no_ack: true,
        # allow_direct: true,
        placement: placement)
      expect(resp).to be_a NATS::JetStream::API::StreamCreateResponse
      # expect(resp.config.allow_direct).to eql(true)
      expect(resp.config.no_ack).to eql(true)
      expect(resp.config.placement).to eql(placement)

      nc.close
    end

    it "should support jsm.stream_info" do
      nc.jsm.add_stream(name: "a")
      info = nc.jsm.stream_info("a")
      expect(info).to be_a NATS::JetStream::API::StreamInfo
      expect(info.state).to be_a NATS::JetStream::API::StreamState
      expect(info.config).to be_a NATS::JetStream::API::StreamConfig
      expect(info.created).to be_a Time
      nc.close
    end

    it "should support jsm.update_stream" do
      nc.jsm.add_stream(name: "a", subjects: ["foo"])
      nc.jsm.update_stream(name: "a", subjects: ["foo", "bar"])
      info = nc.jsm.stream_info("a")
      expect(info.config.subjects).to eql(["foo", "bar"])
      nc.close
    end

    it "should fail jsm.update_stream when stream does not exist" do
      expect do
        nc.jsm.update_stream(name: "a", subjects: ["foo", "bar"])
      end.to raise_error(NATS::JetStream::Error::StreamNotFound)
      nc.close
    end

    it "should support jsm.delete_stream" do
      stream_name = "stream-to-delete"
      info = nc.jsm.add_stream(name: stream_name)
      stream_info = nc.jsm.stream_info(stream_name)
      expect(info.config).to eql(stream_info.config)
      ok = nc.jsm.delete_stream(stream_name)
      expect(ok).to eql(true)

      expect do
        nc.jsm.stream_info(stream_name)
      end.to raise_error NATS::JetStream::Error::NotFound
    end

    it "should support jsm.add_consumer" do
      stream_name = "add-consumer-test"
      nc.jsm.add_stream(name: stream_name, subjects: ["foo"])

      # Create durable consumer
      consumer_config = {
        durable_name: "test-create",
        ack_policy: "explicit",
        max_ack_pending: 20,
        max_waiting: 3,
        ack_wait: 5
      }
      resp = nc.jsm.add_consumer(stream_name, consumer_config)
      expect(resp).to be_a NATS::JetStream::API::ConsumerInfo
      expect(resp.stream_name).to eql(stream_name)
      expect(resp.name).to eql("test-create")

      # Create ephemeral consumer (with deliver subject).
      inbox = nc.new_inbox
      consumer_config = {
        deliver_subject: inbox,
        ack_policy: "explicit",
        max_ack_pending: 20,
        ack_wait: 5 # seconds
      }
      consumer = nc.jsm.add_consumer(stream_name, consumer_config)
      expect(consumer).to be_a NATS::JetStream::API::ConsumerInfo
      expect(consumer.stream_name).to eql(stream_name)
      expect(consumer.name).to_not eql("")
      expect(consumer.config.deliver_subject).to eql(inbox)

      js = nc.jetstream
      js.publish("foo", "Hello World!")

      # Now lookup the consumer using the ephemeral name.
      nc.jsm.consumer_info(stream_name, consumer.name)

      # Fetch with pull subscribe.
      psub = js.pull_subscribe("foo", "test-create")
      msgs = psub.fetch
      expect(msgs.count).to eql(1)
      msgs.each do |msg|
        msg.ack_sync
      end

      # Fetch with ephemeral.
      sub = nc.subscribe(inbox)
      msg = sub.next_msg(timeout: 1)
      resp = msg.ack_sync
      expect(resp).to_not be_nil

      expect do
        sub.next_msg(timeout: 0.5)
      end.to raise_error NATS::Timeout

      # Create durable consumer
      {
        durable_name: "test-create2",
        num_replicas: 3
      }
      # It should fail to set replicas since not enough nodes.
      # expect do
      #   nc.jsm.add_consumer(stream_name, consumer_config)
      # end.to raise_error NATS::JetStream::Error::ServerError
    end

    it "should support jsm.add_consumer with ack_policy none" do
      stream_name = "ack-none"
      nc.jsm.add_stream(name: stream_name, subjects: ["foo"])

      # The server omits ack_wait from consumers that do not ack.
      info = nc.jsm.add_consumer(stream_name, durable_name: "pull", ack_policy: "none")
      expect(info.config.ack_policy).to eql("none")
      expect(info.config.ack_wait).to be_nil
      info = nc.jsm.consumer_info(stream_name, "pull")
      expect(info.config.ack_wait).to be_nil

      info = nc.jsm.add_consumer(stream_name, durable_name: "push", ack_policy: "none", deliver_subject: nc.new_inbox)
      expect(info.config.ack_wait).to be_nil

      # Consumers that ack still get the default ack_wait, in seconds.
      info = nc.jsm.add_consumer(stream_name, durable_name: "explicit", ack_policy: "explicit")
      expect(info.config.ack_wait).to eq(30)
      nc.close
    end

    it "should support jsm.delete_consumer" do
      stream_name = "to-delete"
      consumer_name = "dur"
      nc.jsm.add_stream(name: stream_name)
      nc.jsm.add_consumer(stream_name, {durable_name: consumer_name})
      nc.jsm.consumer_info(stream_name, consumer_name)
      ok = nc.jsm.delete_consumer(stream_name, consumer_name)
      expect(ok).to eql(true)
    end

    it "should support jsm.find_stream_name_by_subject" do
      stream_req = {
        name: "foo",
        subjects: ["a", "a.*"]
      }
      resp = nc.request("$JS.API.STREAM.CREATE.foo", stream_req.to_json)
      expect(resp).to_not be_nil

      stream_req = {
        name: "bar",
        subjects: ["b", "b.*"]
      }
      resp = nc.request("$JS.API.STREAM.CREATE.bar", stream_req.to_json)
      expect(resp).to_not be_nil

      js = nc.jetstream
      stream = js.find_stream_name_by_subject("a")
      expect(stream).to eql("foo")

      stream = js.find_stream_name_by_subject("a.*")
      expect(stream).to eql("foo")

      stream = js.find_stream_name_by_subject("b")
      expect(stream).to eql("bar")

      stream = js.find_stream_name_by_subject("b.*")
      expect(stream).to eql("bar")

      expect do
        js.find_stream_name_by_subject("c")
      end.to raise_error(NATS::JetStream::Error::NotFound)

      expect do
        js.find_stream_name_by_subject("c")
      end.to raise_error(NATS::JetStream::API::Error)

      expect do
        js.find_stream_name_by_subject("c", timeout: 0.00001)
      end.to raise_error(NATS::Timeout)

      nc.close
    end

    it "should support jsm.consumer_info" do
      nc = NATS.connect(@s.uri)

      stream_req = {
        name: "quux",
        subjects: ["q"]
      }
      resp = nc.request("$JS.API.STREAM.CREATE.quux", stream_req.to_json)
      expect(resp).to_not be_nil

      consumer_req = {
        stream_name: "quux",
        config: {
          durable_name: "test",
          ack_policy: "explicit",
          max_ack_pending: 20,
          max_waiting: 3,
          ack_wait: 5 * 1_000_000_000 # 5 seconds
        }
      }
      resp = nc.request("$JS.API.CONSUMER.DURABLE.CREATE.quux.test", consumer_req.to_json)
      expect(resp).to_not be_nil

      js = nc.jetstream

      js.publish("q", "hello world")

      info = js.consumer_info("quux", "test")
      expect(info.type).to eql("io.nats.jetstream.api.v1.consumer_info_response")

      # It is a struct so either is ok.
      expect(info.num_pending).to eql(1)
      expect(info[:num_pending]).to eql(1)
      expect(info.stream_name).to eql("quux")
      expect(info.name).to eql("test")

      # Cannot modify the response.
      expect do
        info.num_pending = 10
      end.to raise_error(FrozenError)

      expect do
        js.consumer_info("quux", "missing")
      end.to raise_error(NATS::JetStream::API::Error)

      expect do
        js.consumer_info("quux", "missing")
      end.to raise_error(NATS::JetStream::Error::NotFound)
    end
  end
end
