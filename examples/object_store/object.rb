# frozen_string_literal: true

require "nats"

client = NATS.connect
os = client.object_store

store = os.stores.create(
  bucket: "text",
  description: "text objects"
)

object = store.put(name: "string", data: "data")

object.info
object.update(description: "description")

object.link? # false
object.deleted? # false

object.delete
object.deleted? # false
