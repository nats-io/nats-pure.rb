# frozen_string_literal: true

require "nats"

client = NATS.connect

service = client.services.add(
  name: "calc",
  version: "1.0.0",
  description: "description"
)

service.on_stop do
  puts "Service stopped at #{Time.now}"
end

service.endpoints.add("min") do |message|
  min = JSON.parse(message.data).min
  message.respond(min.to_json)
end

service.endpoints.add("max") do |message|
  max = JSON.parse(message.data).max
  message.respond(max.to_json)
end

min = client.request("min", [5, 100, -7, 34].to_json)
max = client.request("max", [5, 100, -7, 34].to_json)

puts "min = #{min.data}, max = #{max.data}"

service.stop
