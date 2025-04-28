# frozen_string_literal: true

require "nats"

client = NATS.connect
js = client.js

stream = js.streams.create(
  name: "stream",
  subjects: ["foo.*"]
)

thread = Thread.new do
  step = 0

  loop do
    sleep 0.5

    100.times do |index|
      js.publish("foo.#{index}", "data #{step}-#{index}")
    end

    step += 1
  end
end

consumer = stream.consumers.upsert(
  name: "consumer",
  ack_policy: "explicit"
)

consume = consumer.consume do |message|
  puts message.data
  message.ack
end

sleep 5

thread.exit
consume.stop

consumer.delete
stream.delete

client.close
