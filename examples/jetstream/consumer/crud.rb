# frozen_string_literal: true

require "nats"

client = NATS.connect
js = client.js

stream = js.streams.create(
  name: "stream",
  subjects: ["foo", "bar"]
)

foo = stream.consumers.create(
  name: "foo",
  filter_subject: "foo"
)

bar = stream.consumers.upsert(
  name: "bar",
  filter_subject: "bar"
)

foo.update(description: "foo consumer")
bar.update(description: "bar consumer")

puts foo.info
puts bar.info

foo.delete
bar.delete

stream.delete
client.close
