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

stream.consumers.names.each do |name|
  puts "Consumer #{name}"
end
# Consumer consumer_0
# ...
# Consumer consumer_5

stream.consumers.names(offset: 3).each do |name|
  puts "Offset #{name}"
end
# Offset consumer_3
# Offset consumer_4

stream.consumers.each(&:delete)
stream.delete
client.close
