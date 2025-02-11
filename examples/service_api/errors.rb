# frozen_string_literal: true

client = NATS.connect

service = client.services.add(
  name: "calc",
  version: "1.0.0",
  description: "description"
)

service.endpoints.add("raise-error") do |message|
  raise "raise error"
end

service.endpoints.add("class-error") do |message|
  message.respond_with_error(StandardError.new("class error"))
end

service.endpoints.add("string-error") do |message|
  message.respond_with_error("string error")
end

service.endpoints.add("hash-error") do |message|
  message.respond_with_error(code: 503, description: "hash error")
end

puts client.request("raise-error").header
puts client.request("class-error").header
puts client.request("string-error").header
puts client.request("hash-error").header

service.stop
