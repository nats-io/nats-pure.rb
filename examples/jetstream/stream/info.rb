# frozen_string_literal: true

require "nats"

client = NATS.connect
js = client.js

stream = js.streams.add(
  name: "stream",
  subjects: ["foo.bar", "foo.baz", "foo.qux"]
)

5.times do
  js.publish("foo.bar", "bar")
end

10.times do
  js.publish("foo.baz", "baz")
end

20.times do
  js.publish("foo.qux", "qux")
end

stream.info.state
# <NATS::JetStream::Stream::State
#   @messages=35,
#   @bytes=1960,
#   @first_seq=1,
#   @last_seq=35,
#   @subjects=nil,
#   @num_subjects=3,
# ...>

stream.info(subjects_filter: "foo.*").state
# <NATS::JetStream::Stream::State
#   @messages=35,
#   @bytes=1960,
#   @first_seq=1,
#   @last_seq=35,
#   @subjects={:"foo.bar"=>5, :"foo.baz"=>10, :"foo.qux"=>20},
#   @num_subjects=3,
# ...>

stream.info(subjects_filter: "foo.*", offset: 1).state
# <NATS::JetStream::Stream::State
#   @messages=35,
#   @bytes=1960,
#   @first_seq=1,
#   @last_seq=35,
#   @subjects={:"foo.baz"=>10, :"foo.qux"=>20},
#   @num_subjects=3,
# ...>

stream.purge(filter: "foo.bar")
stream.info(deleted_details: true).state
# <NATS::JetStream::Stream::State
#   @messages=30,
#   @bytes=1680,
#   @first_seq=6,
#   @last_seq=35,
#   @deleted=[1, 2, 3, 4, 5],
#   @num_subjects=2,
#   @num_deleted=5,
# ...>

stream.delete
client.close
