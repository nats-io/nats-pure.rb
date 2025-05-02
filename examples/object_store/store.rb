# frozen_string_literal: true

require "nats"

client = NATS.connect
os = client.object_store

# Creating a bucket
store = os.stores.create(
  bucket: "text",
  description: "text objects"
)

# Retrieving a bucket
store = os.stores.find("text")

# Iterating over all buckets
os.stores.each do |store|
  puts store.config
end

# Iterating over all buckets names
os.stores.names.each do |name|
  puts name
end

# Store methods
store.status
store.update(description: "description")
store.seal
store.delete
