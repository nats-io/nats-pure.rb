# frozen_string_literal: true

nats = NATS.connect
js = nats.jetstream # or nats.jsm

stream = js.add_stream(
  name: "stream",
  subjects: %w[hello world]
)

js.publish("hello", "hello")
js.publish("world", "world")

client.close
