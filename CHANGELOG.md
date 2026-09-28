# Change log

## main

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
