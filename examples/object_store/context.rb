# frozen_string_literal: true

require "nats"

client = NATS.connect

os = client.object_store
os = client.object_store(prefix: "$OS.API")
os = client.object_store(domain: "DOMAIN")

js = client.js(domain: "DOMAIN")
os = js.object_store
