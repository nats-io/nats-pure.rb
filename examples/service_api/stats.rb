# frozen_string_literal: true

require "nats"

client = NATS.connect

service = client.services.add(
  name: "calc",
  version: "1.0.0"
)

service.on_stats do |endpoint|
  errors = endpoint.stats.num_errors
  requests = endpoint.stats.num_requests

  { error_rate: (100.0 * errors / requests).round(2) }
end

service.endpoints.add("divide") do |message|
  dividend, divisor = JSON.parse(message.data)
  message.respond((dividend / divisor).to_json)
end

client.request("divide", [5, 2].to_json)
client.request("divide", [7, 0].to_json)
client.request("divide", [3, 1].to_json)
client.request("divide", [4, 2].to_json)
client.request("divide", [8, 0].to_json)

puts <<~INFO
=== Info ===
#{service.info}
INFO

puts <<~STATS
=== Stats ===
#{service.stats}
STATS

service.stop
