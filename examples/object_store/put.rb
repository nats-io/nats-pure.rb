# frozen_string_literal: true

require "nats"

client = NATS.connect
os = client.object_store

store = os.stores.create(
  bucket: "files",
  description: "file objects"
)

string_object = store.put(
  name: "string",
  data: "data"
)

file_object = store.put(
  name: "file",
  data: File.new("path/to/file")
)

io_object = store.put(
  name: "io",
  data: StringIO.new("data")
)

link_object = store.link(
  name: "link", 
  to: string_object
)
