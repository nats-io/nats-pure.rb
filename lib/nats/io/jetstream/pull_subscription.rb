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

        t = MonotonicTime.now
        timeout = params[:timeout] ||= 5
        expires = (timeout * 1_000_000_000) - 100_000
        next_req = {
          batch: batch,
          **params.slice(:group, :min_pending, :min_ack_pending, :priority)
        }

        msgs = []
        case
        when batch < 1
          raise ::NATS::JetStream::Error.new("nats: invalid batch size")
        when batch == 1
          ####################################################
          # Fetch (1)                                        #
          ####################################################

          # Check if there is any pending message in the queue that is
          # ready to be consumed.
          take_pending(msgs, batch)

          # Make lingering request with expiration.
          next_req[:expires] = expires
          if msgs.empty?
            # Make publish request and wait for response.
            pull(next_req)

            # Wait for result of fetch or timeout. Another thread fetching
            # from the subscription can take the message that wakes this
            # one up, and a status that ends a pull, this fetch's or an
            # earlier one's, brings no message: like nats.go, wait on.
            loop do
              remaining = timeout - MonotonicTime.since(t)
              raise ::NATS::Timeout.new("nats: fetch timeout") if remaining <= 0

              synchronize { wait_for_msgs_cond.wait(remaining) }
              msg = pop_pending
              next if msg.nil?
              if JS.is_status_msg(msg)
                next if pull_ended?(msg)

                raise JS.from_msg(msg)
              end
              raise ::NATS::Timeout.new("nats: fetch timeout") if MonotonicTime.since(t) > timeout

              break msgs << msg
            end
          end
        when batch > 1
          ####################################################
          # Fetch (n)                                        #
          ####################################################

          # Check if there already enough in the pending buffer.
          return msgs if take_pending(msgs, batch)

          # Make publish request for the rest and wait any response.
          next_req[:batch] = batch - msgs.size
          next_req[:no_wait] = true
          pull(next_req)

          # Not receiving even one is a timeout.
          start_time = MonotonicTime.now
          msg = nil

          synchronize do
            wait_for_msgs_cond.wait(timeout)

            msg = pop_pending
          end

          # Check if the first message was a response saying that
          # there are no messages.
          if !msg.nil? && JS.is_status_msg(msg)
            case msg.header[JS::Header::Status]
            when JS::Status::NoMsgs, JS::Status::RequestTimeout
              # No messages now, or other pulls wait for more than are
              # pending (408 Requests Pending), as nats.go does.
              # Make another request that does wait.
              next_req[:expires] = expires
              next_req.delete(:no_wait)

              pull(next_req)
            else
              # An error ends the fetch, with the messages taken before it.
              return msgs unless msgs.empty?

              raise JS.from_msg(msg)
            end
          else
            msgs << msg unless msg.nil?
          end

          # Check if have not received yet a single message.
          duration = MonotonicTime.since(start_time)

          if msgs.empty? && (duration > timeout)
            raise NATS::Timeout.new("nats: fetch timeout")
          end

          needed = batch - msgs.count
          while (needed > 0) && (MonotonicTime.since(start_time) < timeout)
            duration = MonotonicTime.since(start_time)

            # Wait for the rest of the messages.
            synchronize do
              # Wait until there is a message delivered.
              if @pending_queue.empty?
                deadline = timeout - duration
                MonotonicTime.now

                wait_for_msgs_cond.wait(deadline) if deadline > 0

                duration = MonotonicTime.since(start_time)
                if msgs.empty? && @pending_queue.empty? && (duration > timeout)
                  raise NATS::Timeout.new("nats: fetch timeout")
                end
              end

              unless @pending_queue.empty?
                msg = pop_pending

                if JS.is_status_msg(msg)
                  case msg.header[JS::Header::Status]
                  when JS::Status::NoMsgs, JS::Status::RequestTimeout
                    duration = MonotonicTime.since(start_time)

                    if duration > timeout
                      # Only received a subset of the messages.
                      if !msgs.empty?
                        return msgs
                      else
                        raise NATS::Timeout.new("nats: fetch timeout")
                      end
                    end
                  else
                    # An error ends the fetch, with the messages taken before it.
                    return msgs unless msgs.empty?

                    raise JS.from_msg(msg)
                  end

                else
                  # Add to the set of messages that will be returned.
                  msgs << msg
                  needed -= 1
                end
              end
            end # :end: synchronize
          end
        end

        # Check if timed out waiting for messages.
        if msgs.empty? && (MonotonicTime.since(start_time) > timeout)
          raise NATS::Timeout.new("nats: fetch timeout")
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
