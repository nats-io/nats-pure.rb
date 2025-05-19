# frozen_string_literal: true

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

nc.close
