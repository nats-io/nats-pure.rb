# Change log

## main

### Fixed

- `Client#close` could hang forever. It stopped the client's background threads with `Thread#exit`, and killing a thread that is waiting for the client lock can lose Ruby's mutex wakeup, leaving `close` asleep on an unlocked lock (#183). The threads are now asked to stop and joined, on close and on reconnect.
- A close while a reconnect was under way did not stick: the reconnect carried on, connected again and restarted the client, subscriptions included.

### Changed

- With `reconnect: false`, losing the connection now closes the client, as nats.go does: the status becomes `CLOSED`, the close callback is called, and `publish` raises `NATS::IO::ConnectionClosedError`. It used to stay `DISCONNECTED` and keep accepting publishes that were never sent, because the close, started from the read loop, killed the read loop part way through.
