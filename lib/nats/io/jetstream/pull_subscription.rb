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
      # For as long, in seconds, a server with leafnodes or gateways delivers
      # to a new pull without checking for interest in its reply first
      # (defaultGatewayRecentSubExpiration of nats-server).
      UNCHECKED_PULL_AGE = 2

      def self.extended(sub)
        sub.instance_eval do
          # The count of pulls, which names their replies, and the statuses
          # that other fetches took for the fetches waiting for their pulls.
          @pulls = 0
          @pull_ends = {}
        end
      end

      # next_msg is not available for pull based subscriptions.
      # @raise [NATS::JetStream::Error]
      def next_msg(params = {})
        raise ::NATS::JetStream::Error.new("nats: pull subscription cannot use next_msg")
      end

      # fetch pulls a batch of messages from a pull consumer. It returns as
      # soon as it has the batch; otherwise it waits for more messages, and
      # returns those that came once its timeout is up. With :no_wait, it
      # takes what the server delivers at once, without waiting for more.
      #
      # Given a block, it passes each delivery to it as it comes, in the
      # calling thread. Otherwise the messages wait for the fetch to end. The
      # server delivers again those not acked within the ack_wait of the
      # consumer, and the fetch returns each message once, as last delivered.
      # Keep the timeout below the ack_wait, or ack in a block. When the block
      # breaks off the fetch, what the server still delivers to its pull is
      # left to the next fetch.
      #
      # @example Ack each message as it comes.
      #
      #   psub.fetch(100, timeout: 60) do |msg|
      #     process(msg)
      #     msg.ack
      #   end
      #
      # @param batch [Fixnum] Number of messages to pull from the stream.
      # @param params [Hash] Options to customize the fetch request.
      # @option params [Float] :timeout How long to wait for the batch, 5 seconds
      #   by default. The fetch then waits up to a second longer for the server
      #   to end its pull, so that it leaves no message behind. With :no_wait,
      #   how long to wait for what the server holds back, 1 second by default.
      # @option params [Boolean] :no_wait Take what the server delivers at once,
      #   without waiting for more messages: none, an empty Array, when none are
      #   pending, or when other pulls wait for more than are pending. While the
      #   consumer may not deliver more until some are acked (max_ack_pending),
      #   the server holds the pull back, and the fetch returns what it got once
      #   its timeout is up. Messages that come later are left to the next fetch.
      # @option params [String] :group Priority group to pull from, which the pulls
      #   of a consumer with a priority policy must name (requires nats-server v2.11.0).
      # @option params [Integer] :min_pending With the overflow priority policy, deliver
      #   only while the consumer has at least this many messages pending; at least 1.
      # @option params [Integer] :min_ack_pending With the overflow priority policy, deliver
      #   only while at least this many messages await acks; at least 1. Given both
      #   minimums, either will do.
      # @option params [Integer] :priority With the prioritized priority policy, the priority
      #   of the pull, from 0, served first, to 9 (requires nats-server v2.12.0).
      # @yieldparam msg [NATS::Msg] Each delivery, as it comes.
      # @return [Array<NATS::Msg>]
      # @raise [NATS::Timeout] When a fetch that waits got no messages before its timeout.
      # @raise [ArgumentError] When the timeout is not a finite positive number, or a
      #   minimum is not an integer of at least 1.
      # @raise [NATS::JetStream::Error::PinIdMismatch] With the pinned_client priority
      #   policy, when the server turned the pull of the fetch away before it got
      #   messages, as the subscription is no longer pinned: its pin expired or it
      #   was unpinned. The next fetch can be pinned again. The server counts the
      #   priority_timeout of the consumer from each pull it gets, not while a pull
      #   waits, so keep the fetch timeout, plus the time between fetches, below it.
      # @raise [NATS::JetStream::Error] When the server ended the pull of the fetch
      #   with an error before it got messages.
      def fetch(batch = 1, params = {}, &block)
        if batch < 1
          raise ::NATS::JetStream::Error.new("nats: invalid batch size")
        end
        [:min_pending, :min_ack_pending].each do |min|
          value = params[min]
          next if value.nil? || (value.is_a?(Integer) && value >= 1)

          raise ArgumentError.new("nats: #{min} should be an integer of at least 1")
        end
        timeout = params[:timeout] || (params[:no_wait] ? 1 : 5)
        unless timeout.is_a?(Numeric) && timeout.positive? && timeout.finite?
          raise ArgumentError.new("nats: timeout should be a finite positive number")
        end

        deadline = MonotonicTime.now + timeout
        msgs = []
        # Take what earlier pulls delivered first.
        while msgs.size < batch && (msg = next_pending)
          collect(msgs, msg, &block)
        end
        return msgs if msgs.size == batch || (!msgs.empty? && MonotonicTime.now >= deadline)

        # Like the nats.go jetstream package and nats.rs, pull once, for the
        # rest of the batch.
        next_req = {
          batch: batch - msgs.size,
          **params.slice(:group, :min_pending, :min_ack_pending, :priority)
        }
        if params[:no_wait]
          next_req[:no_wait] = true
          pull_pending(msgs, next_req, deadline, &block)
        else
          # The pull expires with the timeout. As nats.go does, wait up to a
          # second longer for the server to end it, so that it leaves nothing
          # behind.
          next_req[:expires] = pull_expires(deadline)
          pull_and_wait(msgs, next_req, deadline + 1, &block)
          raise ::NATS::Timeout.new("nats: fetch timeout") if msgs.empty?
        end
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

      # pull_and_wait sends a pull that waits for messages, with a reply of
      # its own under the subscription, as ADR-13 has it. The messages it
      # delivers carry the subjects of the stream, so that fetches share
      # them, but the status that ends it comes to its reply.
      def pull_and_wait(msgs, next_req, deadline, &block)
        reply = synchronize { "#{@subject.chomp("*")}#{@pulls += 1}" }
        synchronize { @pull_ends[reply] = nil }
        pin_id = pull(next_req, reply)
        receive(msgs, next_req[:batch], pin_id, -> { wait_pending(reply, deadline) }, &block)
      ensure
        synchronize { @pull_ends.delete(reply) }
      end

      # pull_pending sends a pull that does not wait, with a subscription of
      # its own: unsubscribing ends the pull if the server holds it, as it
      # does while the consumer may not deliver more messages.
      def pull_pending(msgs, next_req, deadline, &block)
        inbox = @nc.subscribe(@nc.new_inbox)
        pulled = MonotonicTime.now
        pin_id = pull(next_req, inbox.subject)
        ended = receive(msgs, next_req[:batch], pin_id, -> { next_reply(inbox, deadline) }, &block)
      ensure
        release(inbox, ended ? 0 : pulled + UNCHECKED_PULL_AGE - MonotonicTime.now) if inbox
      end

      # receive collects the messages a pull delivers. It returns true once
      # the pull delivered its batch or the server ended it, and false when
      # nothing came before the deadline.
      def receive(msgs, batch, pin_id, next_msg, &block)
        batch.times do
          msg = next_msg.call
          return false if msg.nil?
          next collect(msgs, msg, &block) unless JS.is_status_msg(msg)

          forget_pin(pin_id) if msg.header[JS::Header::Status] == JS::Status::PinIdMismatch
          # An error ends the fetch too, with the messages taken before it.
          return true if pull_ended?(msg) || !msgs.empty?

          raise JS.from_msg(msg)
        end
        true
      end

      # release unsubscribes the inbox of a pull that did not wait, handing
      # what came to it to the next fetches. Unless the pull ended, it waits
      # until the server checks for interest before it delivers to the pull.
      def release(inbox, linger)
        if linger > 0
          return Thread.new do
            hand_over(inbox, MonotonicTime.now + linger)
            release(inbox, 0)
          end
        end

        begin
          inbox.unsubscribe
        rescue NATS::IO::ConnectionClosedError, NATS::IO::BadSubscription
          # The connection closed, which ended the pull too.
        end
        hand_over(inbox)
      end

      # hand_over adds the messages that come to the inbox of a pull that did
      # not wait, until the deadline, to those of the subscription.
      def hand_over(inbox, deadline = MonotonicTime.now)
        while (msg = next_reply(inbox, deadline))
          keep(msg) unless JS.is_status_msg(msg)
        end
      end

      # keep adds a message to those delivered to the subscription, for the
      # next fetches. Like the connection, it drops the message when the
      # subscription holds as many as it may, and the server delivers it again.
      def keep(msg)
        synchronize do
          return if @pending_queue.size >= pending_msgs_limit || @pending_size >= pending_bytes_limit

          @pending_queue << msg
          @pending_size += msg.data.size
          wait_for_msgs_cond.signal
        end
      end

      # collect adds a message to those of the fetch, and passes it to the
      # block, if there is one. A message the server delivers again, as it
      # was not acked in time, takes the place of its earlier delivery.
      def collect(msgs, msg)
        yield msg if block_given?
        meta = msg.metadata
        if meta && meta.num_delivered > 1
          i = msgs.index { |held| held.metadata.sequence.stream == meta.sequence.stream }
        end
        i ? msgs[i] = msg : msgs << msg
      end

      # pull_ended? tells whether a status only says that a pull ended:
      # 404 No Messages, or 408, as the pull expired or other pulls wait
      # for more messages than are pending. Other statuses are errors.
      def pull_ended?(msg)
        [JS::Status::NoMsgs, JS::Status::RequestTimeout].include?(msg.header[JS::Header::Status])
      end

      # pull_expires is how long a pull may wait, in nanoseconds: until the
      # deadline. Never 0, with which the pull would wait for good.
      def pull_expires(deadline)
        [((deadline - MonotonicTime.now) * 1_000_000_000).to_i, 1].max
      end

      # wait_pending takes the next message delivered to the subscription,
      # or the status that ended the pull of the reply, waiting for one until
      # the deadline; nil when none came. Other fetches can take the message
      # it was woken up for.
      def wait_pending(reply, deadline)
        synchronize do
          loop do
            return @pull_ends.delete(reply) if @pull_ends[reply]

            msg = next_pending(reply)
            return msg if msg

            remaining = deadline - MonotonicTime.now
            return if remaining <= 0

            wait_for_msgs_cond.wait(remaining)
          end
        end
      end

      # next_pending takes the next message delivered to the subscription,
      # or the status that ended the pull of the reply, if there is one.
      # Other statuses ended the pulls of other fetches, which get them if
      # they still wait for them.
      def next_pending(reply = nil)
        synchronize do
          while (msg = pop_pending)
            return msg unless JS.is_status_msg(msg) && msg.subject != reply
            next unless @pull_ends.key?(msg.subject)

            @pull_ends[msg.subject] = msg
            wait_for_msgs_cond.broadcast
          end
        end
      end

      # next_reply takes the next reply to a pull that does not wait,
      # waiting for one until the deadline; nil when none came.
      def next_reply(inbox, deadline)
        msg = inbox.synchronize do
          while inbox.pending_queue.empty?
            remaining = deadline - MonotonicTime.now
            return if remaining <= 0

            inbox.wait_for_msgs_cond.wait(remaining)
          end
          inbox.pending_queue.pop.tap { |reply| inbox.pending_size -= reply.data.size }
        end
        msg.sub = self
        track_pin(msg)
      end

      # pull asks the server for messages, sending the pin id of the
      # subscription, if it is pinned, as the messages it took last say.
      # Returns the pin id it sent.
      def pull(next_req, reply)
        next_req[:id] = synchronize { @pin_id }
        @nc.publish(@jsi.nms, JS.next_req_to_json(next_req), reply)
        next_req[:id]
      end

      # pop_pending takes the next message delivered to the subscription,
      # if there is one: the connection delivers under the same lock, so
      # waiting for one here would stop it.
      def pop_pending
        synchronize do
          return if @pending_queue.empty?

          msg = @pending_queue.pop
          @pending_size -= msg.data.size
          track_pin(msg)
        end
      end

      # track_pin keeps the pin id of the subscription. With the pinned_client
      # priority policy, every message delivered to a pinned subscription
      # carries its pin id, which it sends with its pulls.
      def track_pin(msg)
        pin_id = (msg.header || {})[JS::Header::PinId]
        synchronize { @pin_id = pin_id } if pin_id
        msg
      end

      # forget_pin drops the pin id a pull sent, which the server turned away
      # (423) as the subscription is no longer pinned, unless the subscription
      # got another one since.
      def forget_pin(pin_id)
        synchronize { @pin_id = nil if @pin_id == pin_id }
      end
    end
    private_constant :PullSubscription
  end
end
