# Copyright 2016-2018 The NATS Authors
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
require 'openssl'
require 'erb'

describe 'Client - WebSocket spec' do
  before :each do
    @natsctl = NatsServerControl.init_with_config_from_string(config.result(binding), opts)
    @natsctl.start_server(true)
  end

  after :each do
    @natsctl.kill_server
  end

  context 'when server accepts websocket connections without TLS' do
    let :opts do
      {
        'pid_file' => '/tmp/test-nats-8080.pid',
        'host' => '127.0.0.1',
        'port' => 4080,
        'wsport' => 8080,
      }
    end
    let :config do
      ERB.new(<<~CONF)
        net:  "<%= opts['host'] %>"
        port: <%= opts['port'] %>
        websocket {
          port: <%= opts['wsport'] %>
          no_tls: true
        }
      CONF
    end

    it 'should work' do
      nats = NATS.connect("ws://localhost:8080")

      nats.subscribe("hello") do |msg, reply|
        nats.publish(reply, 'ok')
      end

      response = nats.request("hello", "world")
      expect(response.data).to eql("ok")
    end
  end

  context 'when server requires TLS for websocket connections' do
    let :opts do
      {
        'pid_file' => '/tmp/test-nats-8443.pid',
        'host' => '127.0.0.1',
        'port' => 4443,
        'wsport' => 8443,
      }
    end
    let :config do
      ERB.new(<<~CONF)
        net:  "<%= opts['host'] %>"
        port: <%= opts['port'] %>
        websocket {
          port: <%= opts['wsport'] %>
          tls {
            cert_file:  "./spec/configs/certs/server.pem"
            key_file:   "./spec/configs/certs/key.pem"
          }
        }
      CONF
    end

    it 'should connect over TLS' do
      tls_context = OpenSSL::SSL::SSLContext.new
      tls_context.set_params
      tls_context.ca_file = "./spec/configs/certs/ca.pem"
      nats = NATS.connect(
         servers: ['wss://localhost:8443'],
         reconnect: false,
         tls: {
           context: tls_context
         }
      )

      nats.subscribe("hello") do |msg, reply|
        nats.publish(reply, 'ok')
      end

      response = nats.request("hello", "world")
      expect(response.data).to eql("ok")
    end
  end
end
