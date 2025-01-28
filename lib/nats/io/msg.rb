# frozen_string_literal: true

# Copyright 2016-2021 The NATS Authors
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

module NATS
  class Msg
    attr_accessor :subject, :reply, :data, :header
    attr_reader :error

    def initialize(opts = {})
      @subject = opts[:subject]
      @reply = opts[:reply]
      @data = opts[:data]
      @header = opts[:header]
      @nc = opts[:nc]
      @sub = opts[:sub]
      @ackd = false
      @meta = nil
      @error = nil
    end

    def respond(data = "")
      return unless @nc
      if header
        dmsg = dup
        dmsg.subject = reply
        dmsg.data = data
        @nc.publish_msg(dmsg)
      else
        @nc.publish(reply, data)
      end
    end

    def respond_with_error(error)
      @error = NATS::Service::ErrorWrapper.new(error)

      message = dup
      message.subject = reply
      message.reply = ""
      message.data = @error.data

      message.header = {
        "Nats-Service-Error" => @error.message,
        "Nats-Service-Error-Code" => @error.code
      }

      respond_msg(message)
    end

    def respond_msg(msg)
      return unless @nc
      @nc.publish_msg(msg)
    end

    def inspect
      hdr = ", header=#{@header}" if @header
      dot = "..." if @data.length > 10
      dat = "#{data.slice(0, 10)}#{dot}"
      "#<NATS::Msg(subject: \"#{@subject}\", reply: \"#{@reply}\", data: #{dat.inspect}#{hdr})>"
    end
  end
end
