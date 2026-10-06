# Change log

## main

### Added

- JetStream: stream configs take the settings added in nats-server 2.10: `compression`, `first_seq`, `subject_transform` and `consumer_limits` (whose `inactive_threshold` is in nanoseconds, like the other stream durations). They used to be dropped, so a stream could not be created with them, and sending a fetched config back as an update left them out.
- JetStream: stream configs take the settings added in nats-server 2.11 to 2.14: `allow_msg_ttl` and `subject_delete_marker_ttl` (2.11; the latter in nanoseconds, like the other stream durations), `allow_msg_counter`, `allow_atomic`, `allow_msg_schedules` and `persist_mode` (2.12), and `allow_batched` (2.14). Like nats.go, the client does not send them at their defaults, such as `false`, as servers since 2.12, and 2.11 ones in strict mode, refuse settings they do not know.
- JetStream: `NATS::JetStream::Header` names the JetStream headers: those for deduplication and optimistic concurrency, such as `MSG_ID` and `EXPECTED_LAST_SUBJECT_SEQUENCE`, and those of nats-server 2.11 to 2.14: `EXPECTED_LAST_SUBJECT_SEQUENCE_SUBJECT`, `MSG_TTL` and `MARKER_REASON` (2.11), the atomic batch headers (2.12; `BATCH_COMMIT` `"eob"` needs 2.14), the message schedule headers (2.12 and 2.14), and `REQUIRED_API_LEVEL` (2.12), which JetStream API requests send as a `header:` option, as in `js.stream_info(name, header: {...})`. It also names the headers that the server sets on the messages it republishes, sources or returns from direct gets, such as `STREAM` and `SEQUENCE`.
- JetStream: `js.publish` takes `ttl:`, the whole seconds after which the stream removes the message, or `:never` to keep it past the stream's `max_age`, for streams with `allow_msg_ttl` (nats-server 2.11). Other values raise `ArgumentError`.
- JetStream: `js.publish` takes `schedule:`, which makes the message a schedule that publishes it to its `target:` subject: once, `at:` a Time (nats-server 2.12), `every:` so many seconds, or on a `cron:` expression with seconds, in UTC or a `time_zone:` (2.14). The schedule can give the messages it publishes a `ttl:` (2.12), and publish the last message of a `source:` subject instead and roll up the target (`rollup: true`) (2.14; 2.12 ignores both). The stream needs `allow_msg_schedules`. An invalid schedule raises `ArgumentError`, before anything is sent; `NATS::JetStream::Header::SCHEDULE_NEXT` and `SCHEDULER` cancel a schedule.
- JetStream: `stream_info` reports the stream's `mirror` and `sources`, including their subject transforms, and both `stream_info` and `consumer_info` report when the server reported the info, as `ts`.
- JetStream: `create_consumer` and `update_consumer` use the create and update actions of nats-server 2.10. Creating a consumer that exists with a different config raises `NATS::JetStream::Error::ConsumerAlreadyExists`, and updating one that does not exist raises `NATS::JetStream::Error::ConsumerDoesNotExist`; both are `BadRequest` errors. An update replaces the whole config, so fields left out take their defaults. `add_consumer` still creates or updates.
- JetStream: `msg.term(reason: "...")` passes the reason on to the server's advisory for the terminated message. Servers before 2.10.4 do not terminate a message given a reason.
- JetStream: consumers can be paused (nats-server 2.11): created paused with `pause_until` in their config, as a `Time` or an RFC 3339 String, or paused and resumed with `pause_consumer` and `resume_consumer`; updating a consumer keeps its pause. `consumer_info` reports whether a consumer is `paused`, and the seconds until it resumes, as `pause_remaining`. Servers before 2.11 create consumers unpaused, and let `pause_consumer` and `resume_consumer` time out.
- JetStream: pull consumers can serve priority groups (nats-server 2.11). Consumer configs take `priority_policy`, `priority_groups` and `priority_timeout` (in seconds, like the other consumer durations), and `consumer_info` reports the state of the groups as `priority_groups`. `fetch` takes the `group` to pull from, `min_pending` and `min_ack_pending` for the `"overflow"` policy, and `priority` for the `"prioritized"` policy of nats-server 2.12.
- JetStream: with the `"pinned_client"` priority policy, a pull subscription keeps the pin id that the server delivers with its messages, and sends it with its pulls. When the server says that the subscription is no longer pinned, as its pin expired or it was unpinned with the new `unpin_consumer`, a fetch that got no messages raises `NATS::JetStream::Error::PinIdMismatch`, and the next fetch can be pinned again. A subscription that does not pull for the consumer's `priority_timeout` loses its pin, and a fetch can wait for its whole timeout without pulling again, so keep the fetch timeout, plus the time between fetches, below it.
- JetStream: `reset_consumer` makes a consumer deliver again from after its ack floor, or from the stream sequence given as `seq` (nats-server 2.14). A sequence that the deliver policy of the consumer does not let it be reset to raises `NATS::JetStream::Error::ConsumerInvalidReset`, a `BadRequest` error, and one that is not an integer of 0 or more raises `ArgumentError`. For a stream or consumer that does not exist, and with servers before 2.14, the request times out.
- JetStream: `stream_info` and `consumer_info` report the `cluster` of the stream or consumer as a Hash, including when its leader was elected, as `leader_since` (nats-server 2.12). `consumer_info` used to drop it.
- KV: buckets can be created with `compression: true` and with `metadata`, which `status.compressed?` and `status.metadata` report.
- KV: `watch` takes an Array of keys, watched by a single consumer (nats-server 2.10). An empty Array watches all keys.

### Changed

- JetStream and KV: settings that used to be dropped are now sent. Code that already passed `compression`, `first_seq`, `subject_transform` or `consumer_limits` to `add_stream`, or `compression` or `metadata` to `create_key_value`, created its streams and buckets without them, so calling it again for an existing stream or bucket now fails with "stream name already in use with a different configuration" (err_code 10058). Apply the setting with `update_stream`, or stop passing it.
- JetStream: the same goes for the settings of nats-server 2.11 to 2.14: code that passed them to `add_stream` created its streams without them, so calling it again for an existing stream now fails with err_code 10058. `update_stream` applies them, except `allow_msg_counter` and `persist_mode`, which a stream cannot change.
- KV: `create_key_value` takes only `true` or `false` for `compression`; anything else, such as `"s2"`, which used to be ignored, raises `ArgumentError`.
- JetStream: `add_consumer` leaves the `ConsumerConfig` it is given unchanged. It used to set its `name` and a default `ack_policy`, and convert its durations to nanoseconds, so passing the same config again sent durations a billion times too long.
- JetStream: two `stream_info` or `consumer_info` results are no longer `==` unless they were reported at the same time, as they now carry `ts`.
- KV: `watch` no longer looks up the bucket's stream before creating its consumer.

### Fixed

- JetStream: `update_stream` with the config from `stream_info` failed with err_code 10052, such as "message TTL status can not be disabled", for streams with per-message TTLs, subject delete markers, counters, message schedules or async persistence, and turned off atomic and fast batches, as `StreamConfig` dropped the settings of nats-server 2.11 to 2.14. It now keeps them.
- JetStream: `js.publish` with `stream:` added `Nats-Expected-Stream` to the header Hash it was given, so a caller that reused the Hash sent it with its later publishes.
- JetStream: `js.publish` raised `ArgumentError: unknown keywords` after the server had stored the message, when publishing to a stream with counters or committing an atomic batch, as the acks of nats-server 2.12 carry `val`, `batch` and `count`. `PubAck` now has these fields and ignores any it does not know, so fields added to acks later cannot break publish. (#192, #177, thanks @jnowakplacewise)
- JetStream: `add_consumer`, `consumer_info`, `subscribe` and `pull_subscribe` raised `NoMethodError` for consumers that do not ack (`ack_policy: "none"`) created without an `ack_wait`, after the consumer had been created. The server omits `ack_wait` for them, and `config.ack_wait` is now `nil`. (#192)
- JetStream: `fetch` took a status that an earlier pull had left in the subscription, such as the 408 of a fetch that timed out, for the reply to its own pull, and raised `NATS::IO::Timeout` at once, even with messages pending: a fetch of more than one message with any such status, a fetch of one message with a second one. With the `"pinned_client"` priority policy, it went on to raise `NATS::JetStream::Error::PinIdMismatch` fetch after fetch. `fetch` now first takes what earlier pulls left, and pulls for the rest only. When no more messages are pending, it returns those at once, as nats.go does, instead of waiting out its timeout. And a fetch that got messages before an error status, such as 409 Consumer Deleted, raised the error and dropped them; like nats.go, it now returns them.
- JetStream: a `fetch` of more than one message raised `NATS::IO::Timeout` at once, although messages were pending, when other pulls of the consumer waited for more messages than were pending, such as the pull of a subscription on standby for the `"pinned_client"` priority policy, or one waiting for a higher `"overflow"` minimum. The server turns the first, non-waiting pull of a fetch away then (408 Requests Pending); like nats.go, `fetch` now pulls again, and waits.
- JetStream: a `fetch` of one message raised `TypeError: nil can't be coerced into Float` when threads fetched from the same subscription at once: woken up for a message that another thread took, it did not wait on. It now waits until its timeout. (#181, thanks @route)
- JetStream: a `fetch` of one message raised `NATS::IO::Timeout` ("nats: fetch request timeout") before its timeout when a status that ended an earlier pull, such as the 408 of a fetch that had just timed out, came while it waited, and left its own message for the next fetch. Like nats.go, it now waits on for its message until its timeout.
- JetStream: `fetch` could miss the reply to its pull when it came before the fetch waited for it, as when its thread was preempted: a fetch of one message then waited out its timeout and raised `NATS::IO::Timeout`, leaving its message to be redelivered after the ack wait, and a fetch of more messages returned only the first one, after its timeout. `fetch` now takes what is there before it waits.
- JetStream: when the first pull of a `fetch` of more than one message found no messages, the fetch pulled again for its whole timeout, counted from then, so that pull outlived the fetch, and left what it got to the next fetch. It now pulls for the time it has left, and only for a 404 or a 408 Requests Pending, not for the 408 that ended an earlier pull.
- KV: after its consumer was recreated, as after a server restart, a watcher yielded the entries of every key in the bucket instead of the watched keys. The recreated consumer now keeps the keys filter. (#192)
- KV: after its consumer was recreated, a watcher yielded its last entry again, and a watcher with no entries yet, such as one on an empty bucket, never got its consumer back (`err_code` 10094) and stayed silent. The recreated consumer now starts after the last entry. (#192, #175, thanks @Xayc73)
- A subscription without a callback, read with `next_msg`, dropped every message and reported `NATS::IO::SlowConsumer` once it had received its `pending_bytes_limit` in all, 64 MiB by default, however fast it was read, as `next_msg` did not take the messages it returned off the pending bytes.

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
