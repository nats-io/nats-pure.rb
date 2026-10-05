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
      # returns at once the messages that are pending.
      #
      # Given a block, it passes each message to it as it comes, in the
      # calling thread. Otherwise the messages wait for the fetch to end. The
      # server delivers again those not acked within the ack_wait of the
      # consumer, and the fetch returns each message once, as last delivered.
      # Keep the timeout below the ack_wait, or ack in a block.
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
      #   by default. The fetch then waits a little longer, up to a second, for
      #   the server to end its pull, so that it leaves no message behind.
      # @option params [Boolean] :no_wait Take only the messages that are pending,
      #   without waiting for more. None is an empty Array, as is no reply from
      #   the server before the timeout, as when the consumer may not deliver
      #   more messages until some are acked (max_ack_pending).
      # @option params [String] :group Priority group to pull from, which the pulls
      #   of a consumer with a priority policy must name (requires nats-server v2.11.0).
      # @option params [Integer] :min_pending With the overflow priority policy, deliver
      #   only while the consumer has at least this many messages pending; at least 1.
      # @option params [Integer] :min_ack_pending With the overflow priority policy, deliver
      #   only while at least this many messages await acks; at least 1. Given both
      #   minimums, either will do.
      # @option params [Integer] :priority With the prioritized priority policy, the priority
      #   of the pull, from 0, served first, to 9 (requires nats-server v2.12.0).
      # @yieldparam msg [NATS::Msg] Each message, as it comes.
      # @return [Array<NATS::Msg>]
      # @raise [NATS::Timeout] When a fetch that waits got no messages before its timeout.
      # @raise [ArgumentError] When the timeout is not a positive number, or a minimum
      #   is not an integer of at least 1.
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
        timeout = params[:timeout] || 5
        unless timeout.is_a?(Numeric) && timeout.positive?
          raise ArgumentError.new("nats: timeout should be a positive number")
        end

        deadline = MonotonicTime.now + timeout
        msgs = []
        # Take what earlier pulls delivered first.
        while msgs.size < batch && (msg = next_pending)
          collect(msgs, msg, &block)
        end
        return msgs if msgs.size == batch

        # Like nats.go and nats.rs, pull once, for the rest of the batch.
        next_req = {
          batch: batch - msgs.size,
          **params.slice(:group, :min_pending, :min_ack_pending, :priority)
        }
        if params[:no_wait]
          next_req[:no_wait] = true
          pull_pending(msgs, next_req, deadline, &block)
        else
          # The pull expires with the timeout. As nats.go does, wait a little
          # longer for the server to end it, so that it leaves nothing behind.
          next_req[:expires] = pull_expires(deadline)
          pull_and_wait(msgs, next_req, deadline + [timeout, 1].min, &block)
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
        pull(next_req, reply)
        receive(msgs, next_req[:batch], -> { wait_pending(reply, deadline) }, &block)
      ensure
        synchronize { @pull_ends.delete(reply) }
      end

      # pull_pending sends a pull that does not wait, with a subscription of
      # its own: unsubscribing ends the pull if the server holds it, as it
      # does while the consumer may not deliver more messages.
      def pull_pending(msgs, next_req, deadline, &block)
        inbox = @nc.subscribe(@nc.new_inbox)
        pull(next_req, inbox.subject)
        receive(msgs, next_req[:batch], -> { next_reply(inbox, deadline) }, &block)
      ensure
        inbox&.unsubscribe
      end

      # receive collects the messages a pull delivers, until it delivered
      # its batch, the server ended it, or none came before the deadline.
      def receive(msgs, batch, next_msg, &block)
        batch.times do
          msg = next_msg.call
          return if msg.nil?
          next collect(msgs, msg, &block) unless JS.is_status_msg(msg)
          # An error ends the fetch too, with the messages taken before it.
          return if pull_ended?(msg) || !msgs.empty?

          raise JS.from_msg(msg)
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
          inbox.pending_queue.pop
        end
        track_pin(msg)
      end

      # pull asks the server for messages, sending the pin id of the
      # subscription, if it is pinned, as the messages it took last say.
      def pull(next_req, reply)
        next_req[:id] = synchronize { @pin_id }
        @nc.publish(@jsi.nms, JS.next_req_to_json(next_req), reply)
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
      # carries its pin id, which it sends with its pulls, until a 423 status
      # says that it is no longer pinned.
      def track_pin(msg)
        header = msg.header || {}
        synchronize do
          if header[JS::Header::Status] == JS::Status::PinIdMismatch
            @pin_id = nil
          elsif header[JS::Header::PinId]
            @pin_id = header[JS::Header::PinId]
          end
        end
        msg
      end
    end
    private_constant :PullSubscription
  end
end
