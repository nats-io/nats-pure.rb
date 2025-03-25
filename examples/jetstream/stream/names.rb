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

js.streams.names.each do |name|
  puts "Stream #{name}"
end
# Stream bar_0
# ...
# Stream foo_4

js.streams.names(offset: 7).each do |name|
  puts "Offset #{name}"
end
# Offset foo_2
# Offset foo_3
# Offset foo_4

js.streams.names(subject: "bar.*").each do |name|
  puts "Bar #{name}"
end
# Bar bar_0
# Bar bar_1
# Bar bar_2
# Bar bar_3
# Bar bar_4

js.streams.each(&:delete)
client.close
