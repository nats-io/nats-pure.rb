# frozen_string_literal: true

require "nats"

client = NATS.connect
js = client.js

stream = js.streams.add(
  name: "stream",
  subjects: ["foo", "bar"]
)

10.times do
  js.publish("foo", "foo")
  js.publish("bar", "bar")
end

stream.info.state
# <NATS::JetStream::Stream::State
#   @messages=20,
#   @bytes=1040,
#   @first_seq=1,
#   @last_seq=20,
#   @deleted=nil,
#   @num_subjects=2,
#   @num_deleted=nil,
# ...>

stream.purge(filter: "foo")stream.purge(filter: "foo")
# <NATS::JetStream::Stream::State
#   @messages=10,
#   @bytes=520,
#   @first_seq=2,
#   @last_seq=20,
#   @deleted=[3, 5, 7, 9, 11, 13, 15, 17, 19],
#   @num_subjects=1,
#   @num_deleted=9,
# ...>

stream.purge(seq: 10)
# <NATS::JetStream::Stream::State
#   @messages=6,
#   @bytes=312,
#   @first_seq=10,
#   @last_seq=20,
#   @deleted=[11, 13, 15, 17, 19],
#   @num_subjects=1,
#   @num_deleted=5,
# ...>

stream.purge(keep: 3)
# <NATS::JetStream::Stream::State
#   @messages=3,
#   @bytes=156,
#   @first_seq=16,
#   @last_seq=20,
#   @deleted=[17, 19],
#   @num_subjects=1,
#   @num_deleted=2,
# ...>

stream.purge
# <NATS::JetStream::Stream::State
#   @messages=0,
#   @bytes=0,
#   @first_seq=21,
#   @last_seq=20,
#   @deleted=nil,
#   @num_subjects=nil,
#   @num_deleted=nil,
# ...>

stream.delete
client.close
