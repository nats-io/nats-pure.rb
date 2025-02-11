# frozen_string_literal: true

client = NATS.connect

service = client.services.add(
  name: "calc",
  version: "1.0.0"
)

service.endpoints.add("nothing") do |message|
  message.respond("nothing")
end

puts <<~PING
=== PING ===
#{client.request("$SRV.PING.calc").data}
PING

puts <<~INFO
=== INFO ===
#{client.request("$SRV.INFO.calc").data}
INFO

puts <<~STATS
=== STATS ===
#{client.request("$SRV.STATS.calc").data}
STATS

service.stop
