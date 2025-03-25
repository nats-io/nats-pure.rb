# frozen_string_literal: true

require "nats"

client = NATS.connect
js = client.js

stream = js.streams.create(
  name: "stream",
  subjects: ["foo", "bar"]
)

js.publish("foo", "foo")
# <NATS::JetStream::Publisher::Ack @domain=nil, @duplicate=nil, @seq=1, @stream="stream">
js.publish("bar", "bar")
# <NATS::JetStream::Publisher::Ack @domain=nil, @duplicate=nil, @seq=2, @stream="stream">

stream.delete
client.close
