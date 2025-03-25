# frozen_string_literal: true

require "nats"

client = NATS.connect
js = client.js

stream = js.streams.add(
  name: "stream",
  subjects: ["foo.*"]
)

1000.times do |index|
  js.publish("foo.#{index}", "data #{index}")
end

consumer = stream.consumers.upsert(
  name: "consumer",
  ack_policy: "explicit"
)

puts "max_messages"
messages = consumer.fetch(
  max_messages: 100,
  expires: 1.to_nsec
)

messages.each do |message|
  puts message.data
  message.ack
end

puts "max_bytes"
messages = consumer.fetch(
  max_bytes: 1024,
  expires: 1.to_nsec
)

messages.each do |message|
  puts message.data
  message.ack
end

consumer.delete
stream.delete
client.close
