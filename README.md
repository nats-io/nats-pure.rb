[![Gem Version](https://badge.fury.io/rb/nats-pure.svg)](https://rubygems.org/gems/nats-pure)
[![License Apache 2.0](https://img.shields.io/badge/License-Apache2-blue.svg)](https://www.apache.org/licenses/LICENSE-2.0)
[![Build](https://github.com/nats-io/nats-pure.rb/workflows/Build/badge.svg)](https://github.com/nats-io/nats-pure.rb/actions)
[![Documentation](https://img.shields.io/badge/docs-link-brightgreen.svg)](https://docs.nats.io/)

# NATS: Pure Ruby Client

A thread safe [Ruby](http://ruby-lang.org) client for the [NATS messaging system](https://nats.io) written in pure Ruby.

## Getting Started

```bash
gem install nats-pure
```

## Basic Usage

```ruby
require 'nats/client'

nats = NATS.connect("demo.nats.io")
puts "Connected to #{nats.connected_server}"

# Simple subscriber
nats.subscribe("foo.>") { |msg, reply, subject| puts "Received on '#{subject}': '#{msg}'" }

# Simple Publisher
nats.publish('foo.bar.baz', 'Hello World!')

# Unsubscribing
sub = nats.subscribe('bar') { |msg| puts "Received : '#{msg}'" }
sub.unsubscribe()

# Requests with a block handles replies asynchronously
nats.request('help', 'please', max: 5) { |response| puts "Got a response: '#{response}'" }

# Replies
sub = nats.subscribe('help') do |msg|
  puts "Received on '#{msg.subject}': '#{msg.data}' with headers: #{msg.header}"
  msg.respond("I'll help!")
end

# Request without a block waits for response or timeout
begin
  msg = nats.request('help', 'please', timeout: 0.5)
  puts "Received on '#{msg.subject}': #{msg.data}"
rescue NATS::Timeout
  puts "nats: request timed out"
end

# Request using a message with headers
begin
  msg = NATS::Msg.new(subject: "help", headers: {foo: 'bar'})
  resp = nats.request_msg(msg)
  puts "Received on '#{resp.subject}': #{resp.data}"
rescue NATS::Timeout => e
  puts "nats: request timed out: #{e}"
end

# Server roundtrip which fails if it does not happen within 500ms
begin
  nats.flush(0.5)
rescue NATS::Timeout
  puts "nats: flush timeout"
end

# Closes connection to NATS
nats.close
```

## JetStream Usage

Introduced in v2.0.0 series, the client can now publish and receive messages from JetStream.

```ruby
require 'nats/client'

nc = NATS.connect("nats://demo.nats.io:4222")
js = nc.jetstream

js.add_stream(name: "mystream", subjects: ["foo"])

Thread.new do
  loop do
    # Periodically publish messages
    js.publish("foo", "Hello JetStream!")
    sleep 0.1
  end
end

psub = js.pull_subscribe("foo", "bar")

loop do
  begin
    msgs = psub.fetch(5)
    msgs.each do |msg|
      msg.ack
    end
  rescue NATS::IO::Timeout
    puts "Retry later..."
  end
end
```

## Service API

The service API allows you to easily [build NATS services](docs/service_api.md).

## Clustered Usage

```ruby
require 'nats/client'

cluster_opts = {
  servers: ["nats://127.0.0.1:4222", "nats://127.0.0.1:4223"],
  dont_randomize_servers: true,
  reconnect_time_wait: 0.5,
  max_reconnect_attempts: 2
}

nats = NATS.connect(cluster_opts)
puts "Connected to #{nats.connected_server}"


nats.on_error do |e|
  puts "Error: #{e}"
end

nats.on_reconnect do
  puts "Reconnected to server at #{nats.connected_server}"
end

nats.on_disconnect do
  puts "Disconnected!"
end

nats.on_close do
  puts "Connection to NATS closed"
end

nats.subscribe("hello") do |msg|
  puts "#{Time.now} - Received: #{msg.data}"
end

n = 0
loop do
  n += 1
  nats.publish("hello", "world.#{n}")
  sleep 0.1
end
```

## TLS

It is possible to setup a custom TLS connection to NATS by passing
an [OpenSSL](http://ruby-doc.org/stdlib-2.3.2/libdoc/openssl/rdoc/OpenSSL/SSL/SSLContext.html) context to the client to be used on connect:

```ruby
tls_context = OpenSSL::SSL::SSLContext.new
tls_context.ssl_version = :TLSv1_2

NATS.connect({
   servers: ['tls://127.0.0.1:4444'],
   reconnect: false,
   tls: {
     context: tls_context
   }
 })
```

## WebSocket

Since NATS Server v2.2 it is possible to connect to a NATS server [using WebSocket](https://docs.nats.io/running-a-nats-service/configuration/websocket).

 1. Add a [`websocket`](https://github.com/imanel/websocket-ruby) gem to your Gemfile:

    ```ruby
    # Gemfile
    gem 'websocket'
    ```

 2. Connect to WebSocket-enabled NATS Server using `ws` or `wss` protocol in URLs (for plain and secure connection respectively):

    ```ruby
    nats = NATS.connect("wss://demo.nats.io:8443")
    ```

 3. Use NATS as usual.

### NKEYS and JWT User Credentials

This requires server with version >= 2.0.0

Starting from [v0.6.0](https://github.com/nats-io/nats-pure.rb/releases/tag/v0.6.0) release of the client,
you can also optionally install [NKEYS](https://github.com/nats-io/nkeys.rb) in order to use
the new NATS v2.0 auth features:

```bash
gem install nkeys
```

NATS servers have a new security and authentication mechanism to authenticate with user credentials and NKEYS. A single file containing the JWT and NKEYS to authenticate against a NATS v2 server can be set with the `user_credentials` option:

```ruby
NATS.connect("tls://connect.ngs.global", user_credentials: "/path/to/creds")
```

This will create two callback handlers to present the user JWT and sign the nonce challenge from the server. The core client library never has direct access to your private key and simply performs the callback for signing the server challenge. The library will load and wipe and clear the objects it uses for each connect or reconnect.

Bare NKEYS are also supported. The nkey seed should be in a read only file, e.g. `seed.txt`.

```bash
> cat seed.txt
# This is my seed nkey!
SUAGMJH5XLGZKQQWAWKRZJIGMOU4HPFUYLXJMXOO5NLFEO2OOQJ5LPRDPM
```

Then in the client specify the path to the seed using the `nkeys_seed` option:

```ruby
NATS.connect("tls://connect.ngs.global", nkeys_seed: "path/to/seed.txt")
```

### Cluster Server Discovery

By default, when you connect to a NATS server that's in a cluster,
the client will take information about servers it doesn't know about yet.
This can be disabled at connection time:

```ruby
NATS.connect(servers: ['nats://127.0.0.1:4444'], ignore_discovered_urls: true)
```

### Ractor Usage

Using NATS within a Ractor requires URI 0.11.0 or greater to be installed.

```ruby
Ractor.new do
  ractor_nats = NATS.connect('demo.nats.io')

  ractor_nats.subscribe('foo') do |msg, reply|
    puts "Received on '#{msg.subject}': '#{msg.data}' with headers: #{msg.header}"
    ractor_nats.publish(reply, 'baz')
  end

  sleep
end

nats = NATS.connect('demo.nats.io')
response = nats.request('foo', 'bar', timeout: 0.5)
puts response.data
```

## License

Unless otherwise noted, the NATS source files are distributed under
the Apache Version 2.0 license found in the LICENSE file.
