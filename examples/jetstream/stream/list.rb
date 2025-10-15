# frozen_string_literal: true

require "nats"

client = NATS.connect
js = client.js

5.times do |index|
  js.streams.create(name: "foo_#{index}", subjects: ["foo.#{index}"])
end

5.times do |index|
  js.streams.create(name: "bar_#{index}", subjects: ["bar.#{index}"])
end

js.streams.each do |stream|
  puts "Stream #{stream.config.name}"
end
# Stream bar_0
# ...
# Stream foo_4

js.streams.with(offset: 7).each do |stream|
  puts "Offset #{stream.config.name}"
end
# Offset foo_2
# Offset foo_3
# Offset foo_4

js.streams.with(subject: "bar.*").each do |stream|
  puts "Bar #{stream.config.name}"
end
# Bar bar_0
# Bar bar_1
# Bar bar_2
# Bar bar_3
# Bar bar_4

js.streams.each(&:delete)
client.close
