# frozen_string_literal: true

require "nats"

client = NATS.connect
js = client.js

stream = js.streams.add(
  name: "stream",
  subjects: ["foo", "bar"]
)

10.times do |index|
  js.publish("foo", "foo_#{index}")
  js.publish("bar", "bar_#{index}")
end

stream.messages.find(seq: 1)
# <NATS::JetStream::StreamMessage @subject=foo, @header={}, @data=foo_0, @seq=1>

stream.messages.find(last_by_subj: "foo")
# <NATS::JetStream::StreamMessage @subject=foo, @header={}, @data=foo_9, @seq=19>

stream.messages.find(next_by_subj: "bar")
# <NATS::JetStream::StreamMessage @subject=bar, @header={}, @data=bar_0, @seq=2>

stream.messages.find(seq: 1).delete
# true

stream.messages.find(seq: 1)
# NATS::JetStream::MessageNotFoundError

client.close
