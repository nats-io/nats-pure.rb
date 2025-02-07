client = NATS.connect

# JetStream

js = client.jetstream

js.info

# Streams

js.streams

stream = js.streams.find(name)
stream = js.streams.add(**config)

stream.update(**config)
stream.purge(**options)
stream.delete
stream.info

# Messages

message = stream.messages.find(options)
message.delete

# Consumers

js.consumers
stream.consumers

consumer = js.consumers.find(name)
consumer = js.consumers.add(**config)
consumer = js.consumers.add_or_update(**config)

consumer.update(**config)
consumer.delete
consumer.info

message = consumer.next

messages = consumer.fetch(max_messages: 10)
messages = consumer.fetch(max_bytes: 1000)

consumer.consume(options) do |message|
end


# Service API

service = client.services.add(**options)
group = service.groups.add(name)

service.endpoints.add(name, options) { }
group.endpoints.add(name, options) { }
