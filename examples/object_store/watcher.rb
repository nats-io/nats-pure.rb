# frozen_string_literal: true

require "nats"

client = NATS.connect
os = client.object_store

store = os.stores.create(bucket: "bucket")

store.put(name: "object_1", data: "data_1")
store.put(name: "object_2", data: "data_2")
store.put(name: "object_3", data: "data_3")

watcher.updates # <NATS::Object @name="object_1">
watcher.updates # <NATS::Object @name="object_2">
watcher.updates # <NATS::Object @name="object_3">
watcher.updates # <NATS::Object::Watcher::Marker>
watcher.updates # nil

store.put(name: "object_4", data: "data_4")
watcher.updates # <NATS::Object @name="object_4">
