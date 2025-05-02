# Object Store

JetStream Object Stores provide a simple and efficient way to store large objects within JetStream. These stores are backed by specially configured streams, optimized for compact and reliable object storage.

The Object Store - also referred to as a bucket - supports a variety of operations, including:
- Creating or updating objects
- Retrieving objects
- Deleting objects
- Listing all objects in a bucket
- Watching for changes to objects in a bucket
- Creating links to other objects or buckets

## Contents

- [Basics](#basics)
- [Stores](#stores)
  - [Store Operations](#store-operations)
  - [Listing Stores](#listing-stores)
  - [Listing Objects](#listing-objects)
- [Objects](#objects)
  - [Put](#put)
  - [Link](#link)
  - [Get](#get)
  - [Object Operations](#object-operations)
- [Watchers](#watchers)
- [Examples](#examples)

## Basics

You can access the Object Store API through an existing JetStream context object, or initialize a new Object Store context using a NATS client:

```ruby
client = NATS.connect

# Object Store for a JetStream
js = client.js
os = js.object_store

# A new Object Store Context
os = client.object_store
```

You can provide `:prefix` or `:domain` to use for underlying JetStream requests:

```ruby
js = client.object_store # requests will go to $JS.API
js = client.object_store(domain: "domain") # to $JS.domain.API
js = client.object_store(prefix: "$PREFIX.JS") # to $PREFIX.JS
```

## Stores

A store or a bucket is represented by a `NATS::Object::Store` object.

### Store Operations

#### Create

To create a new bucket, you can use `#add` or `#create` methods that accept a bucket configuration as its parameters:

```ruby
store = os.stores.add(config)
# or
store = os.stores.create(config)
```

For example, here we create a bucket with name `zip` and storage `file`

```ruby
store = os.stores.create(
  name: "zip",
  storage: "file"
)
```

For a full set of configuration fields, please see [Store Config](../lib/nats/object/store/config.rb).

#### Find

You can also fetch an already existing bucket by its name with `find`:

```ruby
store = os.stores.find("zip")
```

If the bucket does not exists the method will raise `NATS::Object::StoreNotFoundError`.

#### Update

You can update a bucket with `update` which accepts the same parameters as `create`:

```ruby
store.update(description: "zip files")
```

#### Delete

Use `delete` method to delete a bucket:

```ruby
store.delete
```

#### Status

You can get information about a bucket with:

```ruby
store.status
```

#### Seal

You can seal a bucket, meaning that no further changes are allowed on that bucket:

```ruby
store.seal
```

### Listing Stores

Similarly to the JetStream API, the Object Store context provides a few ways to list buckets and bucket names. 

To iterate over all buckets, use `each`:

```ruby
os.stores.each do |store|
  ...
end
```

You can also iterate over bucket names with the `names` method:

```ruby
os.stores.names.each do |name|
  ...
end
```

### Listing Objects

To list all objects in a bucket, use `objects` method:

```ruby
store.objects.each do |object|
  ...
end
```

By default `objects` will return existing objects in a bucket. You can include info about deleted objects by using `:show_deleted` option:

```ruby
store.objects(show_deleted: true).each do |object|
  ...
end
```

## Objects

### Put

You can use `put` method to create an object and upload data to a bucket:

```ruby
object = store.put(name: "object", data: "data")
```

The `data` options accepts data objects of different types, such `String`, `StringIO`, `File`, and `Tempfile`. 

```ruby
string = store.put(
  name: "string",
  data: "data"
)

file = store.put(
  name: "file",
  data: File.new("path/to/file")
)

io = store.put(
  name: "io",
  data: StringIO.new("data")
)
```

You can also provide a custom I/O object by passing an instance that inherits from Ruby’s `IO` class:

```ruby
class CustomIO < IO
  ...
end

custom = store.put(name: "custom", data: CustomIO.new)
```

For a full set of configuration fields, please see [Object Config](../lib/nats/object/put/meta.rb).

### Link

In an Object Store, you can create links to other objects - either within the same bucket or across different buckets - using the `link` method:

```ruby
object = store.put(name: "object", data: "data")
link = store.link(name: "link", to: object)
```

You can also create a link to an object by providing its bucket and name:

```ruby
link = store.link(name: "link", to: {bucket: "bucket", name: "object"})
```

> Only single-level links are supported. Attempting to create a link to another link will raise a `NATS::Object::NoLinkToLinkError`.

### Get

To retrieve an object, use `get` method:

```ruby
object = store.get("object")
```

If no options are provided, the `get` method will retrieve only the object's metadata. To access an object's data, you must explicitly load it using methods such as `read`, `eof?`, and `close` on its data. The data will be loaded into a tempfile.

```ruby
object = store.get("object")

object.info # <NATS::Object::Info>
object.data # <NATS::Object::IO>

object.data.read # data
object.data.close
```

You can also load the object's data immediately by providing the `:as` option:
- `:string` – reads the entire content into memory and returns the data as a string.
- `:file` – writes the data directly to the specified file path. If no path is provided, the data is written to a tempfile.
- `IO` object – streams the data into a temporary file before piping it to the given IO object.

```ruby
string = store.get("object", as: :string)
string.data # String

tempfile = store.get("object", as: :file)
tempfile.data # Tempfile

file = store.get("object", as: :file, path: "path/to/file")
file.data # File

io = store.get("object", as: StringIO.new)
io.data # StringIO
```

### Object Operations

#### Info

You can access object's info with `info` method:

```ruby
object.info
```

#### Update

To update an object, use `update` method:

```ruby
object.update(config)
```

You can update only the object's metadata fields - such as name, description, headers, and metadata. To replace the object's data, use the `put` method instead.

#### Delete

Use `delete` method to delete an object:

```ruby
object.deleted? # false

object.delete
object.deleted? # true
```

When an object is deleted, its metadata is marked as deleted and its data is removed. However, you can still access the deleted object by using the `show_deleted` option with the `get` method.

```ruby
object = store.put("object", data: "data")
object.delete

store.get("object") 
# NATS::Object::ObjectNotFoundError

store.get("object", show_deleted: true) 
# <NATS::Object @name="object" @deleted=true>
```

## Watchers

Object Store Watchers allow you to monitor changes to objects within a specific bucket. By default, a watcher will return the latest metadata for all objects in the bucket upon startup.

```ruby
store.put("object", "data")

watcher = store.watch(options)

watcher.updates # <Object::Info @name=object>
```

> *Note*: Watchers only provide metadata about objects (e.g., object name, bucket name, size). To retrieve the actual object data, use the `get` method.

Watchers can be customized with several configuration options:
- `include_history` – sends historical updates for each object.
- `ignore_deletes` – ignores objects that have been marked as deleted.
- `updates_only` – only returns updates that occur after the watcher starts, excluding objects present before it.

Once all initial metadata has been sent, the watcher will send a special marker - `NATS::Object::Watcher::Marker` - to indicate that the initial scan is complete. After this point, it will only return updates as changes occur in the bucket.

```ruby
store.put("object_1", "data_1")
store.put("object_2", "data_2")

watcher = store.watch(options)

store.put("object_3", "data_3")

watcher.updates # <NATS::Object::Info @name=object_1>
watcher.updates # <NATS::Object::Info @name=object_2>
watcher.updates # <NATS::Object::Watcher::Marker>
watcher.updates # <NATS::Object::Info @name=object_3>
```

Using the `updates` method will block execution until an update is received or the operation times out. You can control the timeout duration using the `timeout` option, which defaults to 5 seconds.

```ruby
watcher.updates(timeout: 10)
```

If no updates are received within the specified timeout period, the method will return `nil`:

```ruby
watcher.updates # nil
```

To stop a watcher from receiving updates, use `stop` method:

```ruby
watcher.stop
```

## Examples

For more examples, refer to [examples/object_store](../examples/object_store) directory.
