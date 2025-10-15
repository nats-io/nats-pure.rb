# frozen_string_literal: true

require "nats"

client = NATS.connect
js = client.js

stream = js.streams.create(
  name: "stream",
  subjects: ["foo", "bar"]
)

stream = js.streams.find("stream")

stream.update(
  description: "foo bar",
  no_ack: true,
  discard: "new"
)

stream.delete
client.close
