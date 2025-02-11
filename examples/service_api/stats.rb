# frozen_string_literal: true

client = NATS.connect

service = client.services.add(
  name: "calc",
  version: "1.0.0",
  description: "description"
)

service.on_stats do |endpoint|
  errors = endpoint.stats.num_errors
  requests = endpoint.stats.num_requests

  { error_rate: (100.0 * errors / requests).round(2) }
end

service.endpoints.add("divide") do |message|
  data = JSON.parse(message.data)
  message.respond((data["dividend"] / data["divisor"]).to_json)
end

client.request("divide", {dividend: 5, divisor: 2}.to_json)
client.request("divide", {dividend: 7, divisor: 0}.to_json)
client.request("divide", {dividend: 3, divisor: 1}.to_json)
client.request("divide", {dividend: 4, divisor: 2}.to_json)
client.request("divide", {dividend: 8, divisor: 0}.to_json)

puts <<~INFO
=== Info ===
#{service.info}
INFO

puts <<~STATS
=== Stats ===
#{service.stats}
STATS

service.stop
