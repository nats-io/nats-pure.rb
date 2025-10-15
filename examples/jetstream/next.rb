# frozen_string_literal: true

require "nats"

client = NATS.connect
js = client.js

stream = js.streams.create(
  name: "stream",
  subjects: ["foo"]
)

5.times do |index|
  js.publish("foo", "data #{index}")
end

consumer = stream.consumers.upsert(
  name: "consumer",
  ack_policy: "explicit",
  ack_wait: 0.1.to_nsec
)

puts "No Ack"
10.times do
  puts consumer.next(expires: 1.to_nsec)
end

puts "With Ack"
10.times do
  message = consumer.next(expires: 1.to_nsec)
  puts message || "No messages"
  message&.ack
end

consumer.delete
stream.delete
client.close
