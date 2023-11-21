# Copyright 2016-2023 The NATS Authors
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

require 'spec_helper'
require 'monitor'
require 'tmpdir'

describe 'JetStream' do
  describe 'NATS v2.10 Features' do
    before(:each) do
      @tmpdir = Dir.mktmpdir("ruby-jetstream")
      @s = NatsServerControl.new("nats://127.0.0.1:4852", "/tmp/test-nats.pid", "-js -sd=#{@tmpdir}")
      @s.start_server(true)
    end

    after(:each) do
      @s.kill_server
      FileUtils.remove_entry(@tmpdir)
    end

    it 'should create pull subscribers with multiple filter subjects' do
      nc = NATS.connect(@s.uri)
      js = nc.jetstream
      js.add_stream(name: "MULTI_FILTER", subjects: ["foo.one.*", "foo.two.*", "foo.three.*"])
      js.add_stream(name: "ANOTHER_MULTI_FILTER", subjects: ["foo.five.*"])

      js.publish("foo.one.1", "1")
      js.publish("foo.two.2", "2")
      js.publish("foo.three.3", "3")
      js.publish("foo.two.2", "22")
      js.publish("foo.one.3", "11")

      # Manually using add_consumer JS API to create an ephemeral.
      expect do
        consumer = js.add_consumer("MULTI_FILTER", {
          name: "my-ephemeral",
          filter_subjects: ["foo.one.*", "foo.two.*"]
        })
        # For ephemerals, have to use nil for both subject and durable options
        sub = js.pull_subscribe(nil, nil, name: "my-ephemeral", stream: "MULTI_FILTER")
        msgs = sub.fetch(5)
        msgs.each do |msg|
          msg.ack
        end
        expect(msgs.count).to eql(4)
        expect(msgs[0].subject).to eql('foo.one.1')
        expect(msgs[1].subject).to eql('foo.two.2')
        expect(msgs[2].subject).to eql('foo.two.2')
        expect(msgs[3].subject).to eql('foo.one.3')
      end.to_not raise_error

      # Manually using add_consumer JS API to create a durable.
      expect do
        consumer = js.add_consumer("MULTI_FILTER", {
          durable_name: "my-durable",
          filter_subjects: ["foo.three.*"]
        })
        # To bind without creating have to use nil for both subject and durable options.
        sub = js.pull_subscribe(nil, nil, name: "my-durable", stream: "MULTI_FILTER")
        msgs = sub.fetch(5)
        msgs.each do |msg|
          msg.ack
        end
        expect(msgs.count).to eql(1)
        expect(msgs[0].subject).to eql('foo.three.3')
      end.to_not raise_error

      # Binding to stream explicitly.
      expect do
        sub = js.pull_subscribe(["foo.one.1", "foo.two.2"], "MULTI_FILTER_CONSUMER", stream: "MULTI_FILTER")
        info = sub.consumer_info
        expect(info.name).to eql('MULTI_FILTER_CONSUMER')
        expect(info.config.durable_name).to eql('MULTI_FILTER_CONSUMER')
        expect(info.config.max_waiting).to eql(512)
        expect(info.num_pending).to eql(3)

        msgs = sub.fetch(5)
        msgs.each do |msg|
          msg.ack
        end
        expect(msgs.count).to eql(3)
        expect(msgs[0].subject).to eql('foo.one.1')
        expect(msgs[1].subject).to eql('foo.two.2')
        expect(msgs[2].subject).to eql('foo.two.2')
        expect(msgs[2].data).to eql('22')
      end.to_not raise_error

      # Creating a single filter consumer using an Array.
      expect do
        config = NATS::JetStream::API::ConsumerConfig.new(max_waiting: 128)
        sub = js.pull_subscribe(["foo.one.1"], "psub2", config: config)
        info = sub.consumer_info
        expect(info.config.max_waiting).to eql(128)
        expect(info.num_pending).to eql(1)

        msgs = sub.fetch(5)
        msgs.each do |msg|
          msg.ack
        end
        expect(msgs[0].subject).to eql('foo.one.1')
        expect(msgs.count).to eql(1)
      end.to_not raise_error

      # Auto creating a consumer via a loookup.
      expect do
        sub = js.pull_subscribe(["foo.one.1", "foo.two.2"], "psub3")
        info = sub.consumer_info
        expect(info.num_pending).to eql(3)

        msgs = sub.fetch(5)
        msgs.each do |msg|
          msg.ack
        end
        expect(msgs[0].subject).to eql('foo.one.1')
        expect(msgs[1].subject).to eql('foo.two.2')
        expect(msgs[2].subject).to eql('foo.two.2')
        expect(msgs.count).to eql(3)
      end.to_not raise_error

      # Auto creating a consumer with stream that does not match.
      expect do
        sub = js.pull_subscribe(["foo.one.1", "foo.four.4"], "psub4")
        info = sub.consumer_info
        expect(info.num_pending).to eql(3)

        msgs = sub.fetch(5)
        msgs.each do |msg|
          msg.ack
        end
        expect(msgs[0].subject).to eql('foo.one.1')
        expect(msgs[1].subject).to eql('foo.two.2')
        expect(msgs[2].subject).to eql('foo.two.2')
        expect(msgs.count).to eql(3)
      end.to raise_error(NATS::JetStream::Error)

      # Auto creating a consumer with stream that is ambiguous.
      expect do
        sub = js.pull_subscribe(["foo.one.1", "foo.one.2", "foo.five.4"], "psub5")
        info = sub.consumer_info
        expect(info.num_pending).to eql(3)

        msgs = sub.fetch(5)
        msgs.each do |msg|
          msg.ack
        end
        expect(msgs[0].subject).to eql('foo.one.1')
        expect(msgs[1].subject).to eql('foo.two.2')
        expect(msgs[2].subject).to eql('foo.two.2')
        expect(msgs.count).to eql(3)
      end.to raise_error(NATS::JetStream::Error)
    end
  end
end
