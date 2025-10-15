# frozen_string_literal: true

require "nats"

client = NATS.connect
os = client.object_store

store = os.stores.create(bucket: "store")
store.put(name: "object", data: "data")

string = store.get("object", as: :string)
string.data # String

tempfile = store.get("object", as: :file)
tempfile.data # Tempfile

file = store.get("object", as: :file, path: "path/to/file")
file.data # File

io = store.get("object", as: StringIO.new)
io.data # StringIO

object = store.get("object")
object.data # NATS::Object::IO 
object.data.read # String
