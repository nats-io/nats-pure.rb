# frozen_string_literal: true

client = NATS.connect

service = client.services.add(
  name: "calc",
  version: "1.0.0",
  description: "description"
)

arth = service.groups.add("arth")
agg = service.groups.add("agg")

arth.endpoints.add("sum") do |message|
  sum = JSON.parse(message.data).sum
  message.respond(sum.to_json)
end

agg.endpoints.add("avg") do |message|
  data = JSON.parse(message.data)
  message.respond((data.sum / data.size.to_f).to_json)
end

sum = client.request("arth.sum", [3, 4, 5, 7].to_json)
avg = client.request("agg.avg", [3, 4, 5, 7].to_json)

puts "sum = #{sum.data}, avg = #{avg.data}"

service.stop
