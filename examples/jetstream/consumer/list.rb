# frozen_string_literal: true

require "nats"

client = NATS.connect
js = client.js

stream = js.streams.create(name: "stream")

5.times do |index|
  stream.consumers.create(
    name: "consumer_#{index}",
    max_messages: 100
  )
end

stream.consumers.each do |consumer|
  puts "Consumer #{consumer.config.name}"
end
# Consumer consumer_0
# ...
# Consumer consumer_5

stream.consumers.with(offset: 3).each do |consumer|
  puts "Offset #{consumer.config.name}"
end
# Offset consumer_3
# Offset consumer_4

stream.consumers.each(&:delete)
stream.delete
client.close
