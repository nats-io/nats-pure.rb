nats_url = ENV.fetch("NATS_URL", "nats://localhost:4222")

# Connection won't be established until the client is used for the first time
# Connection most probably will be made after the fork of the Puma web server.
$nats = NATS::Client.new(nats_url)

# Hint: don't do subscriptions in the initializer as they will be run in
# the app server master process which you probably don't want.
# Do them in a special dedicated processes, see bin/nats-listener script for an example.

# NATS client does request/response and subscription multiplexing from different callers,
# so connection pooling isn't necessary – you can use a single instance for the whole app.
