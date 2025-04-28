# frozen_string_literal: true

require "nats"

client = NATS.connect
js = client.js

stream = js.streams.create(
  name: "stream",
  subjects: ["foo"]
)

100.times do |index|
  js.publish("foo", "data-#{index}")
end

consumer = stream.consumers.upsert(
  name: "consumer"
)

messages = consumer.fetch(max_messages: 200, expires: 10.to_nsec)

messages.count
# 100
messages.error
# <NATS::JetStream::PullMessageError: NATS::JetStream::PullMessageError>
messages.error.message
# <NATS::JetStream::RequestTimeoutMessage @code=408, @description=Request Timeout>

consumer.delete
stream.delete
client.close
