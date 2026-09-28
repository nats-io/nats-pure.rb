# Change log

## main

### Added

- JetStream: stream configs take the settings added in nats-server 2.10: `compression`, `first_seq`, `subject_transform` and `consumer_limits` (whose `inactive_threshold` is in nanoseconds, like the other stream durations). They used to be dropped, so a stream could not be created with them, and sending a fetched config back as an update left them out.
- JetStream: `stream_info` reports the stream's `mirror` and `sources`, including their subject transforms, and both `stream_info` and `consumer_info` report when the server reported the info, as `ts`.
- JetStream: `create_consumer` and `update_consumer` use the create and update actions of nats-server 2.10. Creating a consumer that exists with a different config raises `NATS::JetStream::Error::ConsumerAlreadyExists`, and updating one that does not exist raises `NATS::JetStream::Error::ConsumerDoesNotExist`; both are `BadRequest` errors. An update replaces the whole config, so fields left out take their defaults. `add_consumer` still creates or updates.
- JetStream: `msg.term(reason: "...")` passes the reason on to the server's advisory for the terminated message. Servers before 2.10.4 do not terminate a message given a reason.
- KV: buckets can be created with `compression: true` and with `metadata`, which `status.compressed?` and `status.metadata` report.
- KV: `watch` takes an Array of keys, watched by a single consumer (nats-server 2.10). An empty Array watches all keys.

### Changed

- JetStream and KV: settings that used to be dropped are now sent. Code that already passed `compression`, `first_seq`, `subject_transform` or `consumer_limits` to `add_stream`, or `compression` or `metadata` to `create_key_value`, created its streams and buckets without them, so calling it again for an existing stream or bucket now fails with "stream name already in use with a different configuration" (err_code 10058). Apply the setting with `update_stream`, or stop passing it.
- KV: `create_key_value` takes only `true` or `false` for `compression`; anything else, such as `"s2"`, which used to be ignored, raises `ArgumentError`.
- JetStream: `add_consumer` leaves the `ConsumerConfig` it is given unchanged. It used to set its `name` and a default `ack_policy`, and convert its durations to nanoseconds, so passing the same config again sent durations a billion times too long.
- JetStream: two `stream_info` or `consumer_info` results are no longer `==` unless they were reported at the same time, as they now carry `ts`.
- KV: `watch` no longer looks up the bucket's stream before creating its consumer.

### Fixed

- JetStream: `js.publish` raised `ArgumentError: unknown keywords` after the server had stored the message, when publishing to a stream with counters or committing an atomic batch, as the acks of nats-server 2.12 carry `val`, `batch` and `count`. `PubAck` now has these fields and ignores any it does not know, so fields added to acks later cannot break publish. (#192, #177, thanks @jnowakplacewise)
- JetStream: `add_consumer`, `consumer_info`, `subscribe` and `pull_subscribe` raised `NoMethodError` for consumers that do not ack (`ack_policy: "none"`) created without an `ack_wait`, after the consumer had been created. The server omits `ack_wait` for them, and `config.ack_wait` is now `nil`. (#192)
- KV: after its consumer was recreated, as after a server restart, a watcher yielded the entries of every key in the bucket instead of the watched keys. The recreated consumer now keeps the keys filter. (#192)
- KV: after its consumer was recreated, a watcher yielded its last entry again, and a watcher with no entries yet, such as one on an empty bucket, never got its consumer back (`err_code` 10094) and stayed silent. The recreated consumer now starts after the last entry. (#192, #175, thanks @Xayc73)

## v2.6.0

This release prepares nats-pure for nats-server 2.16, whose new JetStream
acknowledgement format breaks JetStream consumers and KV watchers in earlier
versions, and fixes a deadlock that could hang `Client#close`.

### Changed

- With `reconnect: false`, losing the connection now closes the client, as nats.go does: the status becomes `CLOSED`, the close callback is called, and `publish` raises `NATS::IO::ConnectionClosedError`. It used to stay `DISCONNECTED` and keep accepting publishes that were never sent, because the close, started from the read loop, killed the read loop part way through. (#189)

### Fixed

- JetStream: accept the 11-token acknowledgement subjects that nats-server 2.16 sends by default (the v2 format of ADR-15). Earlier versions fail to read the metadata of every JetStream message from such a server, which breaks pull and push consumers and KV watchers. (#185)
- JetStream: an unrecognized acknowledgement subject raises `NATS::JetStream::Error::NotJSMessage` instead of `NameError`, and subjects whose numeric fields do not parse are rejected. (#185)
- JetStream: message metadata timestamps keep their full nanosecond precision. (#185)
- KV: watchers track their position from message metadata, so they resume after a server restart with either acknowledgement format. (#185)
- `Client#close` could hang forever. It stopped the client's background threads with `Thread#exit`, and killing a thread that is waiting for the client lock can lose Ruby's mutex wakeup, leaving `close` asleep on an unlocked lock. The threads are now asked to stop and joined, on close and on reconnect. (#183, #189)
- A close while a reconnect was under way did not stick: the reconnect carried on, connected again and restarted the client, subscriptions included. (#189)
- A subscription with a concurrency limit could run its callbacks in parallel, and so out of order: an empty pending queue released the concurrency permit twice. (#186)
- A subscription could stop processing messages for good after a reconnect: shutting down the executor during dispatch killed the read loop and leaked the concurrency permit. (#182)
- WebSocket: protocol lines sharing a frame, such as the `PONG` and `INFO` that nats-server 2.12.2 sends together, were misparsed (#174, thanks @artyomb), and bytes that arrived with the reply to the connect handshake were lost. (#182, #186)
- JRuby: a refused connection raises `Errno::ECONNREFUSED`, as on MRI. (#182, #186)

### Improved

- Tested against nats-server 2.14, 2.15 and the upcoming 2.16 (`main`), on Ruby 3.0 to 3.4 and JRuby. (#182, #188)
