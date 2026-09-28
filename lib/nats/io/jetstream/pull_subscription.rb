# frozen_string_literal: true

# Copyright 2021 The NATS Authors
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

require_relative "errors"

module NATS
  class JetStream
    # PullSubscription is included into NATS::Subscription so that it
    # can be used to fetch messages from a pull based consumer from
    # JetStream.
    #
    # @example Create a pull subscription using JetStream context.
    #
    #   require 'nats/client'
    #
    #   nc = NATS.connect
    #   js = nc.jetstream
    #   psub = js.pull_subscribe("foo", "bar")
    #
    #   loop do
    #     msgs = psub.fetch(5)
    #     msgs.each do |msg|
    #       msg.ack
    #     end
    #   end
    #
    # @!visibility public
    module PullSubscription
      # next_msg is not available for pull based subscriptions.
      # @raise [NATS::JetStream::Error]
      def next_msg(params = {})
        raise ::NATS::JetStream::Error.new("nats: pull subscription cannot use next_msg")
      end

      # fetch makes a request to be delivered more messages from a pull consumer.
      #
      # @param batch [Fixnum] Number of messages to pull from the stream.
      # @param params [Hash] Options to customize the fetch request.
      # @option params [Float] :timeout Duration of the fetch request before it expires.
      # @option params [String] :group Priority group to pull from, which the pulls
      #   of a consumer with a priority policy must name (requires nats-server v2.11.0).
      # @option params [Integer] :min_pending With the overflow priority policy, deliver
      #   only while the consumer has at least this many messages pending; at least 1.
      # @option params [Integer] :min_ack_pending With the overflow priority policy, deliver
      #   only while at least this many messages await acks; at least 1. Given both
      #   minimums, either will do.
      # @option params [Integer] :priority With the prioritized priority policy, the priority
      #   of the pull, from 0, served first, to 9 (requires nats-server v2.12.0).
      # @return [Array<NATS::Msg>]
      # @raise [ArgumentError] When a minimum is not an integer of at least 1.
      # @raise [NATS::JetStream::Error::PinIdMismatch] With the pinned_client priority
      #   policy, when the fetch got no messages as the subscription is no longer
      #   pinned: its pin expired or it was unpinned. The next fetch can be pinned
      #   again. A subscription that does not pull for the priority_timeout of the
      #   consumer loses its pin. A fetch pulls as it starts, but can then wait for
      #   its whole timeout without pulling again, so keep the fetch timeout, plus
      #   the time between fetches, below the priority_timeout.
      def fetch(batch = 1, params = {})
        if batch < 1
          raise ::NATS::JetStream::Error.new("nats: invalid batch size")
        end
        [:min_pending, :min_ack_pending].each do |min|
          value = params[min]
          next if value.nil? || (value.is_a?(Integer) && value >= 1)

          raise ArgumentError.new("nats: #{min} should be an integer of at least 1")
        end

        timeout = params[:timeout] ||= 5
        deadline = MonotonicTime.now + timeout
        msgs = []
        # Take what was delivered before this fetch first.
        return msgs if take_pending(msgs, batch)

        # A fetch of one message pulls and waits for it. A fetch of more
        # first asks for the messages that are pending, without waiting.
        no_wait = batch > 1
        next_req = {
          batch: batch - msgs.size,
          **params.slice(:group, :min_pending, :min_ack_pending, :priority)
        }
        if no_wait
          next_req[:no_wait] = true
        else
          next_req[:expires] = pull_expires(deadline)
        end
        pull(next_req)

        while msgs.size < batch && (msg = wait_pending(deadline))
          if !JS.is_status_msg(msg)
            msgs << msg
            no_wait = false
          elsif no_wait && nothing_pending?(msg)
            # As nats.go does, pull again, and wait until the timeout.
            no_wait = false
            next_req.delete(:no_wait)
            next_req[:expires] = pull_expires(deadline)
            pull(next_req)
          elsif !pull_ended?(msg)
            # An error ends the fetch, with the messages taken before it.
            return msgs unless msgs.empty?

            raise JS.from_msg(msg)
          end
          # Otherwise a pull ended, this fetch's or an earlier one's: like
          # nats.go, wait on for messages until the timeout.
        end
        raise ::NATS::Timeout.new("nats: fetch timeout") if msgs.empty?

        msgs
      end

      # consumer_info retrieves the current status of the pull subscription consumer.
      # @param params [Hash] Options to customize API request.
      # @option params [Float] :timeout Time to wait for response.
      # @return [JetStream::API::ConsumerInfo] The latest ConsumerInfo of the consumer.
      def consumer_info(params = {})
        @jsi.js.consumer_info(@jsi.stream, @jsi.consumer, params)
      end

      private

      # take_pending takes up to batch messages delivered before a fetch
      # pulls, skipping the statuses that ended earlier pulls: they are no
      # reply to the fetch's own. Returns whether the fetch is over, as it
      # has its batch, or took messages before an error.
      def take_pending(msgs, batch)
        synchronize do
          while msgs.size < batch && (msg = pop_pending)
            if !JS.is_status_msg(msg)
              msgs << msg
            elsif !pull_ended?(msg)
              # An error ends the fetch, with the messages taken before it.
              return true unless msgs.empty?

              raise JS.from_msg(msg)
            end
          end
          msgs.size == batch
        end
      end

      # pull_ended? tells whether a status only says that a pull ended:
      # 404 No Messages, or 408, as the pull expired or other pulls wait
      # for more messages than are pending. Other statuses are errors.
      def pull_ended?(msg)
        [JS::Status::NoMsgs, JS::Status::RequestTimeout].include?(msg.header[JS::Header::Status])
      end

      # nothing_pending? tells whether a status says that a pull that does
      # not wait got nothing: no messages are pending (404), or other pulls
      # wait for more than are pending (408 Requests Pending). Other 408s
      # end pulls that expired, such as those of earlier fetches.
      def nothing_pending?(msg)
        status, desc = msg.header.values_at(JS::Header::Status, JS::Header::Desc)
        status == JS::Status::NoMsgs || (status == JS::Status::RequestTimeout && desc == "Requests Pending")
      end

      # pull_expires is how long a pull may wait, in nanoseconds: until a
      # little before the fetch gives up, so that the fetch sees it end.
      # Never 0, with which the pull would wait for good.
      def pull_expires(deadline)
        [((deadline - MonotonicTime.now) * 1_000_000_000).to_i - 100_000, 1].max
      end

      # wait_pending takes the next message delivered to the subscription,
      # waiting for one until the deadline, if there is none yet; nil when
      # none came. Other fetches can take the message it was woken up for.
      def wait_pending(deadline)
        synchronize do
          loop do
            msg = pop_pending
            return msg if msg

            remaining = deadline - MonotonicTime.now
            return if remaining <= 0

            wait_for_msgs_cond.wait(remaining)
          end
        end
      end

      # pull asks the server for messages, sending the pin id of the
      # subscription, if it is pinned, as the messages it took last say.
      def pull(next_req)
        next_req[:id] = synchronize { @pin_id }
        @nc.publish(@jsi.nms, JS.next_req_to_json(next_req), @subject)
      end

      # pop_pending takes the next message delivered to the subscription,
      # if there is one: the connection delivers under the same lock, so
      # waiting for one here would stop it.
      # With the pinned_client priority policy, every message delivered to
      # a pinned subscription carries its pin id, which it sends with its
      # pulls, until a 423 status says that it is no longer pinned.
      def pop_pending
        synchronize do
          return if @pending_queue.empty?

          msg = @pending_queue.pop
          @pending_size -= msg.data.size
          header = msg.header || {}
          if header[JS::Header::Status] == JS::Status::PinIdMismatch
            @pin_id = nil
          elsif header[JS::Header::PinId]
            @pin_id = header[JS::Header::PinId]
          end
          msg
        end
      end
    end
    private_constant :PullSubscription
  end
end
