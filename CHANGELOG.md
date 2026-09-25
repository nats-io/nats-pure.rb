# Change log

## main

### Fixed

- `Client#close` could hang forever. It stopped the client's background threads with `Thread#exit`, and killing a thread that is waiting for the client lock can lose Ruby's mutex wakeup, leaving `close` asleep on an unlocked lock (#183). The threads are now asked to stop and joined, on close and on reconnect.
