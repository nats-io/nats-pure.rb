# JetStream Simplified API

JetStream is a built-in persistence engine that enables messages to be stored and replayed later.
The new API aims to replace the current JetStream implementation by providing a more straightforward approach to working
with JetStream and reducing the number of options users are confronted with.

Key differences between the new and legacy APIs include:
- using smaller, simpler interfaces to manage streams and consumers,
- using a more granular and predictable approach to consuming messages from a stream,
- allowing consumers to receive incoming messages continuously.

## Contents

- [Basics](#basics)
- [Streams](#streams)
  - [Stream Managment](#stream-management)
  - [Stream-specific Operations](#stream-specific-operations)
  - [Listings Streams](#listing-streams)
  - [Stream Messages](#stream-messages)
- [Consumers](#consumers)
  - [Consumer Managment](#consumer-management)
  - [Listings Consumers](#listing-consumers)
- [Publishing](#publishing)
- [Receiving Messages](#receiving-messages)
  - [Fetch](#fetch)
  - [Next](#next)
  - [Consume](#consume)
  - [Message Acknowledgment](#message-acknowledgment)

## Basics

The new JetStream API consists of three main components:
- Context - serves as an entry point to the API and provides methods for creating/finding streams and publishing messages
- Stream - represents a stream in JetStream, allows to manage its configuration, consumers, and messages
- Consumer - represents a consumer in JetStream, allows for configuration management, and provides multiple approaches to receiving messages.

To acces the simplified API, you can manually initialize a JetStream context object or use `js` method on a NATS client:

```ruby
client = NATS.connect

js = NATS::JetStream::Context.new(client)
# or simply
js = client.js
```

Please note that NATS `jetstream` and `jsm` methods return an entry point for the legacy API.

You can provide `:prefix` or `:domain` to use for JetStream requests:

```ruby
js = client.js # requests will go to $JS.API
js = client.js(domain: "domain") # to $JS.domain.API
js = client.js(prefix: "$PREFIX.JS") # to $PREFIX.JS
```

## Streams

In the new API, each stream is represented by a `NATS::JetStream::Stream` object. A stream object allows you to manage consumers for a specific stream, as well as performing stream-specific operations, such as purging, fetching and deleting messages by sequence number, fetching stream info.

### Stream Management

#### Create

To create a new stream, you can use `#add` or `#create` methods that accept a stream configuration as its parameters:

```ruby
stream = js.streams.add(config)
# or
stream = js.streams.create(config)
```

For example, here we create a stream with name `stream` and subjects `foo` and `bar`:

```ruby
stream = js.streams.create(
  name: "stream",
  subjects: ["foo", "bar"],
)
```

For a full set of configuration fields, please see [Stream Config](../lib/nats/jetstream/stream/config.rb).

#### Find

You can also fetch an already existing stream by its name with `#find`:

```ruby
stream = js.streams.find("stream")
```

If the stream does not exists the method will raise `NATS::JetStream::StreamNotFoundError`.

#### Update

You can update a stream with `update` which accepts the same parameters as `create`. However, not all fields are editable after the stream is created, so please refer to [Stream Configuration docs](https://docs.nats.io/nats-concepts/jetstream/streams#configuration) for more details.

```ruby
stream.update(
  description: "foo bar",
  no_ack: true,
  discard: "new"
)
```

#### Delete

Use `delete` method to delete a stream:

```ruby
stream.delete
```

### Stream-specific Operations

The stream object also provides a few stream-specific operations for retrieving its information and deleting messages from a stream.

#### Info

You can get information about a stream with:

```ruby
stream.info(options)
```

The options are:
- `:detailed_details` - when true will result in a full list of deleted message IDs being returned in the info response
- `:subjects_filters` - when set will return a list of subjects and how many messages they hold for all matching subjects
- `:offset` - paging offset when retrieving pages of subject details.

For more information on the info structure, please refer to [Stream Info](../lib/nats/jetstream/stream/info.rb).

#### Purge

To remove messages from a stream, use `purge` method:

```ruby
stream.purge(options)
```

It accepts the following parameters:
- `:filter` - restricts purging to messages that match this subject
- `:seq` - purges all messages up to but not including the message with this sequence. Can be combined with subject filter but not the keep option.
- `:keep` - ensures this many messages are present after the purge. Can be combined with the subject filter but not the sequence.

### Listing Streams

The JetStream context object provides a few ways to list streams and stream names.

To iterate over all streams, use `each`:

```ruby
js.streams.each do |stream|
  ...
end
```

You can filter streams by subject and offset using `with` method:
- `:subject` - limits the list to streams matching this subject filter
- `:offset` - paging offset.

```ruby
js.streams.with(options).each do |stream|
  ...
end
```

You can also iterate over stream names with the `names` method that accepts the same options as `with`:

```ruby
js.streams.names.each do |name|
  ...
end
```

### Stream Messages

The stream object allows you to manage stream messages by retrieving and deleting them.

You can fetch a message from a stream using the message sequence number or its subject:

```ruby
message = stream.messages.find(options)
```

The options are:
- `:seq` - stream sequence number of the message to retrieve, cannot be combined with `:last_by_subj`
- `:last_by_subj` - retrieves the last message for a given subject, cannot be combined with `:seq`
- `:next_by_subj` - combined with sequence gets the next message for a subject with the given sequence or higher.

Use `delete` method to delete a message:

```ruby
message.delete
```

## Consumers

A `NATS::JetStream::Consumer` object represents a JetStream consumer and provides methods for its management and consuming messages.

### Consumer Management

#### Create

You can use `#add` or `#create` methods on a stream to create a consumer. These methods accept a consumer configuration:

```ruby
consumer = stream.consumers.add(config)
# or
consumer = stream.consumers.create(config)
```

For example, here we create a durable consumer by providing `durable_name` option:

```ruby
consumer = stream.consumers.create(
  durable_name: "consumer",
  ack_policy: "all"
)
```

For a full list of configuration options, see [Consumer Config](../lib/nats/jetstream/consumer/config.rb).

#### Upsert

For updating an existing consumer or creating a new one, you can use `upsert` or `add_or_update` methods that accept the same configuration options as `create`:

```ruby
consumer = stream.consumers.upsert(
  durable_name: "consumer",
  ack_policy: "all"
)
```

#### Find

You can fetch an already existing consumer by its name with `#find`:

```ruby
ConsumerNotFoundError`.

#### Update

You can update a consumer with `update` which accepts the same parameters as `create`. However, not all fields are editable after a consumer is created, so please refer to [Consumer Configuration docs](https://docs.nats.io/nats-concepts/jetstream/consumers#configuration) for more details.

```ruby
consumer.update(
  description: "a durable consumer",
  ack_wait: false,
  filter_subjects: ["foo"]
)
```

#### Delete

Use `delete` method to delete a consumer:

```ruby
consumer.delete
```

#### Config & Info

You can access the consumer configuration with `config`, or get its information with `info` method:

```ruby
consumer.config
consumer.info
```

For more information on the info structure, please refer to [Consumer Info](../lib/nats/jetstream/consumer/info.rb).

### Listing Consumers

The new API provides a few ways to list consumers and consumer names.

To iterate over all consumers for a given stream, use `each`:

```ruby
stream.consumers.each do |consumer|
  ...
end
```

You can filter consumers by subject and offset using `with` method:
- `subject` - filters the names to those consuming messages matching
- `offset` - paging offset

```ruby
stream.consumers.with(options).each do |consumer|
  ...
end
```

You can also iterate over consumer names with the `names` method that accepts the same options as `with`:

```ruby
stream.consumers.names.each do |consumer|
  ...
end
```

## Publishing

While you can publish messages to a stream with the standard NATS `publish` method, it is advised to use the
JetStream publishing mechanism as it returns an acknowledgment that the message has been successfully published:

```ruby
js.publish(subject, data, options)
```

The method accepts the following parameters:
- `:stream` - asserts the published message is received by some expected stream,
- `:message_id` - client-defined unique identifier for a message that will be used by the server apply de-duplication within the configured Duplicate Window,
- `:last_message_id` - applies optimistic concurrency control at the stream-level. The value is the last expected Nats-Msg-Id and the server will reject a publish if the current ID does not match,
- `:last_seq` - applies optimistic concurrency control at the stream-level. The value is the last expected sequence and the server will reject a publish if the current sequence does not match,
- `:last_subject_seq` - applies optimistic concurrency control at the subject-level. The value is the last expected sequence and the server will reject a publish if the current sequence does not match for the message's subject
- `:rollup` - applies a purge of all prior messages in the stream or at the subject-level. For purging all prior messages in the stream use `stream`, or `sub`,
- `:header` - any custom message headers,
- `:timeout` - timeout for the publish request.

```ruby
stream = js.streams.create(
  name: "stream",
  subjects: ["foo", "bar"]
)

js.publish("foo", "foo")
# <NATS::JetStream::Publisher::Ack @domain=nil, @duplicate=nil, @seq=1, @stream="stream">

js.publish("bar", "bar")
# <NATS::JetStream::Publisher::Ack @domain=nil, @duplicate=nil, @seq=2, @stream="stream">
```
## Receiving Messages

The JetStream APIs allow a client to express the buffering strategy for reading a stream
at a pace the client can sustain and how the reading happens.

The JetStream API supports three strategies for retrieving messages:
- request the next message, i.e., one message at a time
- request the next N messages
- continuously request and maintain a buffer of N messages.

The first two options allow the client to control and manage its buffering manually.
When the client is done processing the messages, it can, at its discretion,
request additional messages or not.

The last option auto-buffers messages for the client, thus controlling the message and data rates.
The client specifies how many messages it wants to receive, and as it consumes them, the pull requests
additional messages in an effort to prevent the consumer from stalling and thus maximize performance.

### Message

All messages received through a consumer are of `NATS::JetStream::Message`. It has all the standard
fields of a NATS `Msg` and provides functionality for inspecting metadata encoded into the message's
reply subject. This metadata includes:

- `sequence` or `seq` - the sequence information for the message
- `num_delivered` - the number of times this message was delivered to the consumer
- `num_pending` - the number of messages that match the consumer's filter but have not been delivered yet
- `timestamp` - the time the message was originally stored on a stream
- `stream` - the stream name this message is stored on
- `consumer` - the consumer name this message was delivered to
- `domain` - the domain this message was received on.

### Next

The simplest mechanism to process messages is to request a single message with `next`:

```ruby
message = consumer.next(options)
```

It will block until the message is received or the request has expired. When no messages are available,
or an error occurs during the retrieval, the request will return `nil`.

The method takes two optional arguments:
- `:expires` - amount of time to wait for the request to expire (in nanoseconds). Minimum is 1 second, defaults to 30 seconds.
- `:idle_heartbeat` - amount idle time the server should wait before sending a heartbeat. Minimum is 500ms, maximum is 30 seconds. Defaults to half of `expires`.

### Fetch

You can request multiple messages at a time with `fetch`:

```ruby
messages = consumer.fetch(options)

messages.each do |message|
  puts message
end
```

The request is a long poll, and it will block until the desired number of messages is received or the expires time triggers.
This means that the number of messages you request is only a hint, and it is just the upper bound on the number of messages you will receive.

By default, `fetch` will retrieve 100 messages in a batch, but you can control how many messages you receive with options:

- `:max_messages` - max number of messages to return, cannot be combined with `max_bytes`
- `:max_bytes` - max number of bytes to return, cannot be combined with `max_messages`
- `:expires` - amount of time to wait for the request to expire (in nanoseconds). Minimum is 1 second, defaults to 30 seconds.
- `:idle_heartbeat` - amount idle time the server should wait before sending a heartbeat. Minimum is 500ms, maximum is 30 seconds, defaults to half of `expires`.

### Consume

With the first two operations, your application retrieves messages manually. This allows you to
maintain control over whether you want to receive one or multiple messages in a single request.

A third option, `consume`, automates the re-requesting process for additional messages:

```ruby
consumer.consume(options) do |message|
  puts message
end
```

It monitors incoming messages and requests more to maintain your processing momentum. The `consume`
operation maintains an internal buffer of messages that auto-refreshes whenever a percent of
the initial buffer is consumed. This allows the client to process messages in a loop forever.

Unlike `fetch` and `next` the operation won't block your execution process and will continue until
you stop it or an unrecoverable error occurs:

```ruby
consume = consumer.consume do |message|
  puts message
end

sleep 5
consume.stop
```

It accepts the following options:

- `:max_messages` - max number of messages stored in the buffer
- `:max_bytes` - max number of bytes stored in the buffer
- `:expires` - amount of time to wait for a single pull request to expire (in nanoseconds). Minimum is 1 second, defaults to 30 seconds.
- `:idle_heartbeat` - amount of idle time the server should wait before sending a heartbeat. Minimum is 500ms, maximum is 30 seconds, defaults to half of `expires`.
- `:threshold_messages` - number of messages left in the buffer that should trigger a low watermark on the client, and influence it to request more messages
- `:threshold_bytes` - number of bytes left in buffer that should trigger a low watermark on the client, and influence it to request more data.

You can use `max_messages` and `max_bytes` at the same time, but this is an advanced option and
should be used with caution. Most of the time, `max_messages` or `max_bytes` should be used instead.
Note that the byte limit should never be set to a value lower than the maximum message size expected
from the server. If the byte limit is lower than the maximum message size, the consumer will stall
and cannot consume messages.

### Message Acknowledgment

Consumers are responsible for monitoring the delivery and acknowledgments of messages. This tracking ensures that a consumer will automatically attempt to re-deliver the message if it is not acknowledged (un-acked or 'nacked').

```ruby
consumer.consume do |message|
  puts message
  message.ack
end
```

There are four ways to acknowledge a message:
- `ack` - indicates that the message has been processed, and the server will not send it again.
- `nak(delay:)` - informs the server that you failed to process the message, and it should be resent. If `delay` is specified, the message will be resent after the indicated value.
- `in_progress` - notifies the server that you are still working on the message, thus preventing it from being redelivered.
- `term(reason:)` - indicates that you failed to process the message and instructs the server not to send it again (to any consumer).

### Error Handling

```ruby
messages = consumer.fetch(max_messages: 100)

messages.count
# 15
messages.fetch.error
# <NATS::JetStream::PullTimeoutError: pull request timeout>
```

```ruby
consume = consumer.consume do |message|
  puts message
  raise ""
end

consume.error
# <RuntimeError: error>
```

- `NATS::JetStream::NoHeartbeatError`
- `NATS::JetStream::PullTimeoutError`
- `NATS::JetStream::PullMessageError`
- any other Ruby error
