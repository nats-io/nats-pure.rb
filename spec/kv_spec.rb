# frozen_string_literal: true

describe "KeyValue" do
  before do
    @tmpdir = Dir.mktmpdir("ruby-jetstream")
    @s = NatsServerControl.new("nats://127.0.0.1:4621", "/tmp/test-nats.pid", "-js -sd=#{@tmpdir}")
    @s.start_server(true)
  end

  after do
    @s.kill_server
    FileUtils.remove_entry(@tmpdir)
  end

  it "should support access to KeyValue stores" do
    nc = NATS.connect(@s.uri)

    js = nc.jetstream
    kv = js.create_key_value(bucket: "TEST", history: 5, ttl: 3600)
    status = kv.status
    expect(status.bucket).to eql("TEST")
    expect(status.values).to eql(0)
    expect(status.history).to eql(5)
    expect(status.ttl).to eql(3600)

    revision = kv.put("hello", "world")
    expect(revision).to eql(1)

    entry = kv.get("hello")
    expect(entry.revision).to eql(1)
    expect(entry.value).to eql("world")

    status = kv.status
    expect(status.bucket).to eql("TEST")
    expect(status.values).to eql(1)

    100.times do |i|
      kv.put("hello.#{i}", "Hello JS KV! #{i}")
    end

    status = kv.status
    expect(status.bucket).to eql("TEST")
    expect(status.values).to eql(101)

    entry = kv.get("hello.99")
    expect(entry.revision).to eql(101)
    expect(entry.value).to eql("Hello JS KV! 99")

    kv.delete("hello")

    expect do
      kv.get("hello")
    end.to raise_error(NATS::KeyValue::KeyNotFoundError)

    js.delete_key_value("TEST")

    expect do
      js.key_value("TEST")
    end.to raise_error(NATS::KeyValue::BucketNotFoundError)
  end

  it "should report when bucket is not found or invalid" do
    nc = NATS.connect(@s.uri)

    js = nc.jetstream
    expect do
      js.key_value("FOO")
    end.to raise_error(NATS::KeyValue::BucketNotFoundError)

    js.add_stream(name: "KV_foo")
    js.publish("KV_foo", "bar")

    sub = js.subscribe("KV_foo")
    msg = sub.next_msg
    msg.ack

    cinfo = sub.consumer_info
    expect(cinfo.num_pending).to eql(0)

    expect do
      js.key_value("foo")
    end.to raise_error(NATS::KeyValue::BadBucketError)
  end

  it "should support access to KeyValue stores from multiple instances" do
    nc = NATS.connect(@s.uri)

    js = nc.jetstream
    kv = js.create_key_value(bucket: "TEST2")
    ("a".."z").each do |l|
      kv.put(l, l * 10)
    end

    nc2 = NATS.connect(@s.uri)
    js2 = nc2.jetstream
    kv2 = js2.key_value("TEST2")
    a = kv2.get("a")
    expect(a.value).to eql("aaaaaaaaaa")

    nc.close
    nc2.close
  end

  it "should support get by revision" do
    nc = NATS.connect(@s.uri)
    js = nc.jetstream
    kv = js.create_key_value(bucket: "TEST", history: 5, ttl: 3600, description: "Basic KV")

    si = js.stream_info("KV_TEST")
    config = NATS::JetStream::API::StreamConfig.new(
      name: "KV_TEST",
      description: "Basic KV",
      subjects: ["$KV.TEST.>"],
      allow_rollup_hdrs: true,
      deny_delete: true,
      deny_purge: false,
      discard: "new",
      duplicate_window: 120 * ::NATS::NANOSECONDS,
      max_age: 3600 * ::NATS::NANOSECONDS,
      max_bytes: -1,
      max_consumers: -1,
      max_msg_size: -1,
      max_msgs: -1,
      max_msgs_per_subject: 5,
      mirror: nil,
      no_ack: nil,
      num_replicas: 1,
      placement: nil,
      retention: "limits",
      sealed: false,
      sources: nil,
      storage: "file",
      republish: nil,
      allow_direct: false,
      mirror_direct: false
    )
    # v2.11 changes
    if ENV["NATS_SERVER_VERSION"] == "main"
      config.metadata = {
        "_nats.level": "1",
        "_nats.ver": "2.11.0-dev",
        "_nats.req.level": "0"
      }
    end
    expect(config).to eql(si.config)

    # Nothing from start
    expect do
      kv.get("name")
    end.to raise_error(NATS::KeyValue::KeyNotFoundError)

    # Simple put
    revision = kv.put("name", "alice")
    expect(revision).to eql(1)

    # Simple get
    result = kv.get("name")
    expect(result.revision).to eq(1)
    expect(result.value).to eql("alice")

    # Delete
    ok = kv.delete("name")
    expect(ok)

    # Deleting then getting again should be a not found error still,
    # although internally this is a KeyDeletedError.
    expect do
      kv.get("name")
    end.to raise_error(NATS::KeyValue::KeyNotFoundError)

    # Recreate with different name.
    revision = kv.create("name", "bob")
    expect(revision).to eql(3)

    # Expect last revision to be 4.
    expect do
      kv.delete("name", last: 4)
    end.to raise_error(NATS::JetStream::Error::BadRequest)

    # Correct revision should work.
    revision = kv.delete("name", last: 3)
    expect(revision).to eql(4)

    # Conditional Updates.
    revision = kv.update("name", "hoge", last: 4)
    expect(revision).to eql(5)

    # Should fail since revision number not the latest.
    expect do
      revision = kv.update("name", "hoge", last: 3)
    end.to raise_error NATS::KeyValue::KeyWrongLastSequenceError

    # Update with correct latest.
    revision = kv.update("name", "fuga", last: revision)
    expect(revision).to eql(6)

    # Create a different key.
    revision = kv.create("age", "2038")
    expect(revision).to eql(7)

    # Get current.
    entry = kv.get("age")
    expect(entry.value).to eql("2038")
    expect(entry.revision).to eql(7)

    # Update the new key.
    revision = kv.update("age", "2039", last: revision)
    expect(revision).to eql(8)

    # Get latest.
    entry = kv.get("age")
    expect(entry.value).to eql("2039")
    expect(entry.revision).to eql(8)

    # Internally uses get msg API instead of get last msg.
    entry = kv.get("age", revision: 7)
    expect(entry.value).to eql("2038")
    expect(entry.revision).to eql(7)

    # Getting past keys with the wrong expected subject is an error.
    expect do
      kv.get("age", revision: 6)
    end.to raise_error NATS::KeyValue::KeyNotFoundError
    begin
      kv.get("age", revision: 6)
    rescue => e
      expect(e.message).to eql(
        %(nats: key not found: expected '$KV.TEST.age', but got '$KV.TEST.name')
      )
    end
    expect do
      kv.get("age", revision: 5)
    end.to raise_error NATS::KeyValue::KeyNotFoundError
    expect do
      kv.get("age", revision: 4)
    end.to raise_error NATS::KeyValue::KeyNotFoundError

    expect do
      entry = kv.get("name", revision = 3)
      expect(entry.value).to eql("bob")
    end

    # match="nats: wrong last sequence: 8")
    expect do
      kv.create("age", "1")
    end.to raise_error NATS::KeyValue::KeyWrongLastSequenceError
    begin
      kv.create("age", "1")
    rescue => e
      expect(e.message).to eql("nats: wrong last sequence: 8")
    end

    # Now let's delete and recreate.
    kv.delete("age", last: 8)
    kv.create("age", "final")

    expect do
      kv.create("age", "1")
    end.to raise_error NATS::KeyValue::KeyWrongLastSequenceError

    begin
      kv.create("age", "1")
    rescue => e
      expect(e.message).to eql("nats: wrong last sequence: 10")
    end

    entry = kv.get("age")
    expect(entry.revision).to eql(10)

    # Purge
    status = kv.status
    expect(status.values).to eql(9)

    kv.purge("age")
    status = kv.status
    expect(status.values).to eql(6)

    kv.purge("name")
    status = kv.status
    expect(status.values).to eql(2)

    expect do
      kv.get("name")
    end.to raise_error NATS::KeyValue::KeyNotFoundError

    expect do
      kv.get("age")
    end.to raise_error NATS::KeyValue::KeyNotFoundError

    nc.close
  end

  it "should support direct get" do
    nc = NATS.connect(@s.uri)
    js = nc.jetstream
    kv = js.create_key_value(
      bucket: "TESTDIRECT",
      history: 5,
      ttl: 3600,
      description: "KV DIRECT",
      direct: true
    )
    si = js.stream_info("KV_TESTDIRECT")
    expect(si.config.allow_direct).to eql(true)
    kv.create("A", "1")
    kv.create("B", "2")
    kv.create("C", "3")
    kv.create("D", "4")
    kv.create("E", "5")
    kv.create("F", "6")

    kv.put("C", "33")
    kv.put("D", "44")
    kv.put("C", "333")

    msg = js.get_msg("KV_TESTDIRECT", seq: 1, direct: true)
    expect(msg.data).to eql("1")
    expect(msg.subject).to eql("$KV.TESTDIRECT.A")

    entry = kv.get("A")
    expect(entry.key).to eql("A")
    expect(entry.value).to eql("1")

    expect do
      kv.get("Z")
    end.to raise_error NATS::KeyValue::KeyNotFoundError

    # Check with low level msg APIs.

    # last by subject
    msg = js.get_msg("KV_TESTDIRECT", subject: "$KV.TESTDIRECT.C", direct: true)
    expect(msg.data).to eql("333")

    # next by subject
    msg = js.get_msg("KV_TESTDIRECT", subject: "$KV.TESTDIRECT.C", seq: 4, next: true, direct: true)
    expect(msg.data).to eql("33")

    # Malformed request
    expect do
      js.get_msg("KV_TESTDIRECT", subject: "$KV.TESTDIRECT.C", seq: -1, next: true, direct: true)
    end.to raise_error NATS::JetStream::Error::APIError

    # binding to a key value
    kv = js.key_value("TESTDIRECT")
    entry = kv.get("A")
    expect(entry.key).to eql("A")
    expect(entry.value).to eql("1")

    kv = js.key_value("TESTDIRECT")
    entry = kv.get("C", revision: 9)
    expect(entry.key).to eql("C")
    expect(entry.value).to eql("333")

    nc.close
  end

  it "should support republish" do
    nc = NATS.connect(@s.uri)
    js = nc.jetstream
    kv = js.create_key_value(
      bucket: "TESTRP",
      direct: true,
      republish: {
        src: ">",
        dest: "bar.>"
      }
    )

    sub = nc.subscribe("bar.>")
    kv.put("hello.world", "Hello World!")
    msg = sub.next_msg
    expect(msg.subject).to eql("bar.$KV.TESTRP.hello.world")
    expect(msg.data).to eql("Hello World!")
    sub.unsubscribe

    kv = js.create_key_value(
      bucket: "TEST_RP_HEADERS",
      direct: true,
      republish: {
        src: ">",
        dest: "quux.>",
        headers_only: true
      }
    )
    sub = nc.subscribe("quux.>")
    kv.put("hello.world", "Hello World!")
    msg = sub.next_msg
    expect(msg.subject).to eql("quux.$KV.TEST_RP_HEADERS.hello.world")
    expect(msg.data).to eql("")
    expect(msg.header["Nats-Msg-Size"]).to eql("12")
    sub.unsubscribe

    nc.close
  end

  major, minor, _ = RUBY_VERSION.split(".")
  it "should support watch" do
    skip "watch requires ruby >= 3.2" if (major >= "3") && (minor < "2")

    nc = NATS.connect(@s.uri)
    js = nc.jetstream
    kv = js.create_key_value(
      bucket: "WATCH"
    )

    # Same as watch all the updates.
    w = kv.watchall

    # First update when there are no pending entries will be None
    # to mark that there are no more pending updates.
    e = w.updates(timeout: 1)
    expect(e).to eql(nil)

    kv.create("name", "alice:1")
    e = w.updates
    expect(e.delta).to eql(0)
    expect(e.key).to eql("name")
    expect(e.value).to eql("alice:1")
    expect(e.revision).to eql(1)

    kv.put("name", "alice:2")
    e = w.updates
    expect(e.key).to eql("name")
    expect(e.value).to eql("alice:2")
    expect(e.revision).to eql(2)

    kv.put("name", "alice:3")
    e = w.updates
    expect(e.key).to eql("name")
    expect(e.value).to eql("alice:3")
    expect(e.revision).to eql(3)

    kv.put("age", "22")
    e = w.updates
    expect(e.key).to eql("age")
    expect(e.value).to eql("22")
    expect(e.revision).to eql(4)

    kv.put("age", "33")
    e = w.updates
    expect(e.bucket).to eql("WATCH")
    expect(e.key).to eql("age")
    expect(e.value).to eql("33")
    expect(e.revision).to eql(5)

    kv.delete("age")
    e = w.updates
    expect(e.bucket).to eql("WATCH")
    expect(e.key).to eql("age")
    expect(e.value).to eql("")
    expect(e.revision).to eql(6)
    expect(e.operation).to eql("DEL")

    kv.purge("name")
    e = w.updates
    expect(e.bucket).to eql("WATCH")
    expect(e.key).to eql("name")
    expect(e.value).to eql("")
    expect(e.revision).to eql(7)
    expect(e.operation).to eql("PURGE")

    # No new updates at this point...
    expect do
      w.updates(timeout: 0.5)
    end.to raise_error NATS::Timeout

    # Stop the watcher.
    w.stop

    # Now try wildcard matching and make sure we only get last value when starting.
    kv.create("new", "hello world")
    kv.put("t.name", "a")
    kv.put("t.name", "b")
    kv.put("t.age", "c")
    kv.put("t.age", "d")
    kv.put("t.a", "a")
    kv.put("t.b", "b")

    w = kv.watch("t.*")

    # There are values present so nil is _not_ sent to as an update.
    e = w.updates
    expect(e.bucket).to eql("WATCH")
    expect(e.delta).to eql(3)
    expect(e.key).to eql("t.name")
    expect(e.value).to eql("b")
    expect(e.revision).to eql(10)
    expect(e.operation).to eql(nil)

    e = w.updates
    expect(e.bucket).to eql("WATCH")
    expect(e.delta).to eql(2)
    expect(e.key).to eql("t.age")
    expect(e.value).to eql("d")
    expect(e.revision).to eql(12)
    expect(e.operation).to eql(nil)

    e = w.updates
    expect(e.bucket).to eql("WATCH")
    expect(e.delta).to eql(1)
    expect(e.key).to eql("t.a")
    expect(e.value).to eql("a")
    expect(e.revision).to eql(13)
    expect(e.operation).to eql(nil)

    # Consume next pending update.
    e = w.updates
    expect(e.bucket).to eql("WATCH")
    expect(e.delta).to eql(0)
    expect(e.key).to eql("t.b")
    expect(e.value).to eql("b")
    expect(e.revision).to eql(14)
    expect(e.operation).to eql(nil)

    # There are no more updates so client will be sent a marker to signal
    # that there are no more updates.
    e = w.updates
    expect(e).to eql(nil)

    # After getting the empty marker, subsequent watch attempts will be a timeout error.
    expect do
      w.updates(timeout: 1)
    end.to raise_error NATS::Timeout

    kv.put("t.hello", "hello world")
    e = w.updates
    expect(e.delta).to eql(0)
    expect(e.key).to eql("t.hello")
    expect(e.revision).to eql(15)

    # Default watch timeout should 5 minutes
    ci = js.consumer_info("KV_WATCH", w._sub.jsi.consumer)
    expect(ci.config.idle_heartbeat).to eql(5)
    expect(ci.config.inactive_threshold).to eql(300)

    # using meta only
    w = kv.watchall(meta_only: true)
    entries = w.take(2)
    expect(entries.first.key).to eql("age")
    expect(entries.first.value).to be_empty
    expect(entries.last.key).to eql("name")
    expect(entries.last.value).to be_empty

    nc.close
  end

  it "should support history" do
    skip "watch requires ruby >= 3.2" if (major >= "3") && (minor < "2")

    nc = NATS.connect(@s.uri)
    nc.on_error do |e|
      puts e
    end
    js = nc.jetstream
    kv = js.create_key_value(
      bucket: "WATCHHISTORY",
      history: 10
    )
    status = kv.status
    expect(status.stream_info.config.max_msgs_per_subject).to eql(10)

    50.times { |i| kv.put("age", i.to_s) }

    vl = kv.history("age").to_a
    expect(vl.size).to eql(10)

    i = 0
    vl.each do |entry|
      expect(entry.key).to eql("age")
      expect(entry.revision).to eql(i + 41)
      expect(entry.value.to_i).to eql(i + 40)
      i += 1
    end

    expect do
      w = kv.history("nothing")
      w.take(1)
    end.to raise_error NATS::KeyValue::NoKeysFoundError

    expect do
      js.create_key_value(
        bucket: "TOOLARGE",
        history: 65
      )
    end.to raise_error NATS::KeyValue::KeyHistoryTooLargeError

    nc.close
  end

  it "should support using watchers as enumerables" do
    nc = NATS.connect(@s.uri)
    js = nc.jetstream
    kv = js.create_key_value(
      bucket: "WATCH"
    )

    w = kv.watch("users.*")

    1.upto(100).each do |n|
      kv.create("users.#{n}", "A")
    end

    entries = w.take(10)

    # FIXME: First was a empty marker, should continue taking instead?
    expect(entries.size).to eql(9)
    expect(entries.first.key).to eql("users.1")
    expect(entries.last.key).to eql("users.9")

    entries = w.take(1)
    expect(entries.first.key).to eql("users.10")

    entries = w.take(10)
    expect(entries.size).to eql(10)
    expect(entries.first.key).to eql("users.11")
    expect(entries.last.key).to eql("users.20")

    w.stop

    # Can still peek after stopped.
    entries = w.take(1)
    expect(entries.first.key).to eql("users.21")

    nc.close
  end

  it "should support keys" do
    skip "watch requires ruby >= 3.2" if (major >= "3") && (minor < "2")

    nc = NATS.connect(@s.uri)
    nc.on_error do |e|
      puts e
    end
    js = nc.jetstream
    kv = js.create_key_value(
      bucket: "KVS",
      history: 2
    )

    expect do
      w = kv.keys
      w.take(1)
    end.to raise_error NATS::KeyValue::NoKeysFoundError
    expect(kv.status.stream_info.config.max_msgs_per_subject).to eql(2)

    kv.put("a", "1")
    kv.put("b", "2")
    kv.put("a", "11")
    kv.put("b", "22")
    kv.put("a", "111")
    kv.put("b", "222")

    keys = kv.keys.to_a
    expect(keys.size).to eql(2) # last_per_subject

    # Using a block with each
    keys = []
    kv.keys.each do |entry|
      keys.append(entry)
    end
    expect(keys.size).to eql(2)

    # Now delete some.
    kv.delete("a")

    # Should skip deleted entries
    keys = kv.keys.select { |key| key == "a" }
    expect(keys.size).to eql(0)
    keys = kv.keys.reject { |key| key == "a" }
    expect(keys.size).to eql(1)
    kv.keys do |key|
      expect(key).to_not eql("a")
    end
    expect(kv.keys.to_a).to eql(["b"])

    kv.purge("b")

    expect do
      kv.keys.take(1)
    end.to raise_error NATS::KeyValue::NoKeysFoundError

    kv.create("c", "3")
    expect(kv.keys.to_a.size).to eql(1)
    expect(kv.keys.to_a).to eql(["c"])

    nc.close
  end
end
