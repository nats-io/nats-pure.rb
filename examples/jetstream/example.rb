# frozen_string_literal: true

client = NATS.connect

# JetStream

js = client.jetstream

js.info

# Streams

js.streams

js.streams.find(name)
stream = js.streams.add(**config)

stream.update(**config)
stream.purge
stream.delete
stream.info

# Messages

message = stream.messages.find(options)
message.delete

# Consumers

js.consumers

js.consumers.find(name)
js.consumers.add(**config)
consumer = js.consumers.add_or_update(**config)

consumer.update(**config)
consumer.delete
consumer.info

consumer.next

consumer.fetch(max_messages: 10)
consumer.fetch(max_bytes: 1000)

consumer.consume(options) do |message|
end
