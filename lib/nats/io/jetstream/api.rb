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
require "base64"
require "time"

module NATS
  class JetStream
    # JetStream::API are the types used to interact with the JetStream API.
    module API
      # When the server responds with an error from the JetStream API.
      Error = ::NATS::JetStream::Error::APIError

      # SequenceInfo is a pair of consumer and stream sequence and last activity.
      # @!attribute consumer_seq
      #   @return [Integer] The consumer sequence.
      # @!attribute stream_seq
      #   @return [Integer] The stream sequence.
      SequenceInfo = Struct.new(:consumer_seq, :stream_seq, :last_active,
        keyword_init: true) do
        def initialize(opts = {})
          # Filter unrecognized fields and freeze.
          rem = opts.keys - members
          opts.delete_if { |k| rem.include?(k) }
          super
          freeze
        end
      end

      # PriorityGroupState is the state of a priority group of a consumer
      # (requires nats-server v2.11.0).
      #
      # @!attribute group
      #   @return [String] Name of the group.
      # @!attribute pinned_client_id
      #   @return [String, nil] With the pinned_client priority policy, the
      #     pin id of the subscription that the group is pinned to.
      # @!attribute pinned_ts
      #   @return [Time, nil] When the group was pinned.
      PriorityGroupState = Struct.new(:group, :pinned_client_id, :pinned_ts,
        keyword_init: true) do
        def initialize(opts = {})
          opts[:pinned_ts] = JS.parse_time(opts[:pinned_ts])
          rem = opts.keys - members
          opts.delete_if { |k| rem.include?(k) }
          super
          freeze
        end
      end

      # ConsumerInfo is the current status of a JetStream consumer.
      #
      # @!attribute stream_name
      #   @return [String] name of the stream to which the consumer belongs.
      # @!attribute name
      #   @return [String] name of the consumer.
      # @!attribute created
      #   @return [String] time when the consumer was created.
      # @!attribute config
      #   @return [ConsumerConfig] consumer configuration.
      # @!attribute delivered
      #   @return [SequenceInfo]
      # @!attribute ack_floor
      #   @return [SequenceInfo]
      # @!attribute num_ack_pending
      #   @return [Integer]
      # @!attribute num_redelivered
      #   @return [Integer]
      # @!attribute num_waiting
      #   @return [Integer]
      # @!attribute num_pending
      #   @return [Integer]
      # @!attribute cluster
      #   The cluster of a clustered consumer, such as its leader, its
      #   replicas and, as leader_since, when the leader was elected
      #   (requires nats-server v2.12.0); nil on a standalone server. The
      #   values are the server's: leader_since is a String, and the
      #   active of the replicas is in nanoseconds.
      #   @return [Hash, nil]
      # @!attribute ts
      #   When the server reported this info (requires nats-server v2.10.0).
      #   @return [Time]
      # @!attribute paused
      #   True while the consumer is paused (requires nats-server v2.11.0).
      #   @return [Boolean, nil]
      # @!attribute pause_remaining
      #   Seconds until a paused consumer resumes, rounded down, so 0 in its
      #   last second (requires nats-server v2.11.0).
      #   @return [Integer, nil]
      # @!attribute priority_groups
      #   State of the consumer's priority groups (requires nats-server v2.11.0).
      #   @return [Array<PriorityGroupState>, nil]
      ConsumerInfo = Struct.new(:type, :stream_name, :name, :created,
        :config, :delivered, :ack_floor,
        :num_ack_pending, :num_redelivered, :num_waiting,
        :num_pending, :cluster, :push_bound, :ts,
        :paused, :pause_remaining, :priority_groups,
        keyword_init: true) do
        def initialize(opts = {})
          opts[:created] = Time.parse(opts[:created])
          opts[:ts] = Time.parse(opts[:ts]) if opts[:ts]
          opts[:pause_remaining] = opts[:pause_remaining] / ::NATS::NANOSECONDS if opts[:pause_remaining]
          opts[:priority_groups] = opts[:priority_groups].map { |state| PriorityGroupState.new(state) } if opts[:priority_groups]
          opts[:ack_floor] = SequenceInfo.new(opts[:ack_floor])
          opts[:delivered] = SequenceInfo.new(opts[:delivered])
          opts[:config][:ack_wait] = opts[:config][:ack_wait] / ::NATS::NANOSECONDS if opts[:config][:ack_wait]
          opts[:config][:inactive_threshold] = opts[:config][:inactive_threshold] / ::NATS::NANOSECONDS if opts[:config][:inactive_threshold]
          opts[:config][:idle_heartbeat] = opts[:config][:idle_heartbeat] / ::NATS::NANOSECONDS if opts[:config][:idle_heartbeat]
          opts[:config][:priority_timeout] = opts[:config][:priority_timeout] / ::NATS::NANOSECONDS if opts[:config][:priority_timeout]
          opts[:config] = ConsumerConfig.new(opts[:config])
          # Filter unrecognized fields just in case.
          rem = opts.keys - members
          opts.delete_if { |k| rem.include?(k) }
          super
          freeze
        end
      end

      # ConsumerConfig is the consumer configuration.
      #
      # @!attribute durable_name
      #   @return [String]
      # @!attribute deliver_policy
      #   @return [String]
      # @!attribute ack_policy
      #   @return [String]
      # @!attribute ack_wait
      #   Seconds; nil when the server omits it, as for consumers that do not ack.
      #   @return [Integer, nil]
      # @!attribute max_deliver
      #   @return [Integer]
      # @!attribute replay_policy
      #   @return [String]
      # @!attribute max_waiting
      #   @return [Integer]
      # @!attribute max_ack_pending
      #   @return [Integer]
      # @!attribute pause_until
      #   Time until which the consumer delivers no messages, as a Time or
      #   as an RFC 3339 String; a fetched config has a String. The server
      #   takes it only when it creates the consumer: updates keep the pause,
      #   which pause_consumer and resume_consumer change. Requires
      #   nats-server v2.11.0; older ones create the consumer unpaused.
      #   @return [Time, String, nil]
      # @!attribute priority_policy
      #   How the consumer serves the pulls of its priority groups: "none",
      #   "overflow", "pinned_client", or "prioritized" (requires
      #   nats-server v2.11.0, and v2.12.0 for "prioritized").
      #   @return [String, nil]
      # @!attribute priority_groups
      #   Names of the consumer's priority groups, one of which each pull
      #   has to name (requires nats-server v2.11.0).
      #   @return [Array<String>, nil]
      # @!attribute priority_timeout
      #   With the pinned_client priority policy, seconds after which a
      #   pinned subscription that stops pulling is unpinned
      #   (requires nats-server v2.11.0).
      #   @return [Integer, nil]
      ConsumerConfig = Struct.new(:name, :durable_name, :description,
        :deliver_policy, :opt_start_seq, :opt_start_time,
        :ack_policy, :ack_wait, :max_deliver, :backoff,
        :filter_subject, :replay_policy, :rate_limit_bps,
        :sample_freq, :max_waiting, :max_ack_pending,
        :flow_control, :idle_heartbeat, :headers_only,
        # Pull based options
        :max_batch, :max_expires,
        # Push based consumers
        :deliver_subject, :deliver_group,
        # Ephemeral inactivity threshold
        :inactive_threshold,
        # Generally inherited by parent stream and other markers,
        # now can be configured directly.
        :num_replicas,
        # Force memory storage
        :mem_storage,
        # NATS v2.10 features
        :metadata, :filter_subjects, :max_bytes,
        # NATS v2.11 features
        :pause_until, :priority_policy, :priority_groups, :priority_timeout,
        keyword_init: true) do
        def initialize(opts = {})
          # Filter unrecognized fields just in case.
          rem = opts.keys - members
          opts.delete_if { |k| rem.include?(k) }
          super
        end
      end

      # ConsumerPauseResponse is the result of pausing or resuming a consumer
      # (requires nats-server v2.11.0).
      #
      # @!attribute paused
      #   @return [Boolean] Whether the consumer is paused.
      # @!attribute pause_until
      #   @return [Time, nil] When the consumer resumes; nil once resumed. A time
      #     in the past does not pause the consumer, and paused is then false.
      # @!attribute pause_remaining
      #   @return [Integer, nil] Seconds until the consumer resumes, rounded down,
      #     so 0 in its last second; nil when it is not paused.
      ConsumerPauseResponse = Struct.new(:paused, :pause_until, :pause_remaining,
        keyword_init: true) do
        def initialize(opts = {})
          opts[:pause_until] = JS.parse_time(opts[:pause_until])
          opts[:pause_remaining] = opts[:pause_remaining] / ::NATS::NANOSECONDS if opts[:pause_remaining]
          rem = opts.keys - members
          opts.delete_if { |k| rem.include?(k) }
          super
          freeze
        end
      end

      # ConsumerResetResponse is the result of resetting a consumer
      # (requires nats-server v2.14.0).
      #
      # @!attribute info
      #   @return [ConsumerInfo] The consumer after the reset.
      # @!attribute reset_seq
      #   @return [Integer] Stream sequence the consumer delivers from. The next
      #     message it delivers can come later, as the first one from there that
      #     matches its filter.
      ConsumerResetResponse = Struct.new(:info, :reset_seq,
        keyword_init: true) do
        def initialize(opts = {})
          reset_seq = opts[:reset_seq]
          super(info: ConsumerInfo.new(opts), reset_seq: reset_seq)
          freeze
        end
      end

      # StreamConfig represents the configuration of a stream from JetStream.
      #
      # Settings left nil are not sent, and neither are the settings of
      # nats-server 2.11 to 2.14 left at their defaults, such as false.
      # Servers since v2.12.0, and v2.11 ones in strict mode, refuse the
      # settings that they do not know.
      #
      # @!attribute type
      #   @return [String]
      # @!attribute config
      #   @return [Hash]
      # @!attribute created
      #   @return [String]
      # @!attribute state
      #   @return [StreamState]
      # @!attribute did_create
      #   @return [Boolean]
      # @!attribute name
      #   @return [String]
      # @!attribute subjects
      #   @return [Array]
      # @!attribute retention
      #   @return [String]
      # @!attribute max_consumers
      #   @return [Integer]
      # @!attribute max_msgs
      #   @return [Integer]
      # @!attribute max_bytes
      #   @return [Integer]
      # @!attribute max_age
      #   @return [Integer]
      # @!attribute max_msgs_per_subject
      #   @return [Integer]
      # @!attribute max_msg_size
      #   @return [Integer]
      # @!attribute discard
      #   @return [String]
      # @!attribute discard_new_per_subject
      #   Whether a subject that holds max_msgs_per_subject messages refuses
      #   new ones, instead of discarding its oldest. Needs discard "new" and
      #   max_msgs_per_subject; the server reports false as nil.
      #   @return [Boolean, nil]
      # @!attribute storage
      #   @return [String]
      # @!attribute num_replicas
      #   @return [Integer]
      # @!attribute duplicate_window
      #   Nanoseconds within which the stream stores a message only once for
      #   each Header::MSG_ID. Unless set, it is 2 minutes, except that
      #   mirrors, and since nats-server v2.14.0 streams with sources, get
      #   none: the messages published to them are not deduplicated.
      #   @return [Integer]
      # @!attribute compression
      #   Storage compression of a file based stream, "s2" or "none"
      #   (requires nats-server v2.10.0).
      #   @return [String]
      # @!attribute first_seq
      #   The sequence of the first message stored in a new stream
      #   (requires nats-server v2.10.0).
      #   @return [Integer]
      # @!attribute subject_transform
      #   Transform applied to the subject of every message stored, as
      #   `{src:, dest:}` (requires nats-server v2.10.0).
      #   @return [Hash]
      # @!attribute consumer_limits
      #   Defaults and upper limits for the stream's consumers, as
      #   `{inactive_threshold:, max_ack_pending:}`. Like the other durations
      #   of a stream, inactive_threshold is in nanoseconds
      #   (requires nats-server v2.10.0).
      #   @return [Hash]
      # @!attribute allow_msg_ttl
      #   Whether messages can be published with a TTL of their own
      #   (requires nats-server v2.11.0). Once enabled, it cannot be
      #   disabled, and before v2.11.2 it cannot be enabled by an update.
      #   @return [Boolean]
      # @!attribute subject_delete_marker_ttl
      #   Nanoseconds to keep the marker that the server leaves when the last
      #   message of a subject expires, at least a second (requires
      #   nats-server v2.11.0). Before v2.11.2 it needs allow_msg_ttl. From
      #   v2.11.2 on, setting it enables allow_msg_ttl and allow_rollup_hdrs,
      #   and allows purges, so an update cannot set it on a stream that
      #   denies them.
      #   @return [Integer]
      # @!attribute allow_msg_counter
      #   Whether the stream holds counters, which cannot change later
      #   (requires nats-server v2.12.0).
      #   @return [Boolean]
      # @!attribute allow_atomic
      #   Whether messages can be published in atomic batches
      #   (requires nats-server v2.12.0).
      #   @return [Boolean]
      # @!attribute allow_msg_schedules
      #   Whether messages can schedule messages (requires nats-server
      #   v2.12.0). Once enabled, it cannot be disabled. Setting it enables
      #   allow_rollup_hdrs and allows purges, so an update cannot set it on
      #   a stream that denies them.
      #   @return [Boolean]
      # @!attribute persist_mode
      #   "async" to acknowledge messages before they are flushed to disk,
      #   or "default"; the server reports the default as nil. It cannot
      #   change later (requires nats-server v2.12.0).
      #   @return [String, nil]
      # @!attribute allow_batched
      #   Whether messages can be published in fast batches
      #   (requires nats-server v2.14.0).
      #   @return [Boolean]
      StreamConfig = Struct.new(
        :name,
        :description,
        :subjects,
        :retention,
        :max_consumers,
        :max_msgs,
        :max_bytes,
        :discard,
        :max_age,
        :max_msgs_per_subject,
        :max_msg_size,
        :storage,
        :num_replicas,
        :no_ack,
        :duplicate_window,
        :placement,
        :mirror,
        :sources,
        :sealed,
        :deny_delete,
        :deny_purge,
        :allow_rollup_hdrs,
        :republish,
        :allow_direct,
        :mirror_direct,
        :metadata,
        :compression,
        :first_seq,
        :subject_transform,
        :consumer_limits,
        :allow_msg_ttl,
        :subject_delete_marker_ttl,
        :allow_msg_counter,
        :allow_atomic,
        :allow_msg_schedules,
        :persist_mode,
        :allow_batched,
        :discard_new_per_subject,
        keyword_init: true
      ) do
        def initialize(opts = {})
          # Filter unrecognized fields just in case.
          rem = opts.keys - members
          opts.delete_if { |k| rem.include?(k) }
          super
        end
      end

      # StreamInfo is the info about a stream from JetStream.
      #
      # @!attribute type
      #   @return [String]
      # @!attribute config
      #   @return [Hash]
      # @!attribute created
      #   @return [String]
      # @!attribute state
      #   @return [Hash]
      # @!attribute domain
      #   @return [String]
      # @!attribute mirror
      #   State of the stream's mirror, such as its lag and subject
      #   transforms, as a Hash.
      #   @return [Hash]
      # @!attribute sources
      #   State of each of the stream's sources, such as its lag and subject
      #   transforms, as Hashes.
      #   @return [Array<Hash>]
      # @!attribute cluster
      #   The cluster of the stream, such as its leader, its replicas and,
      #   as leader_since, when the leader was elected (requires nats-server
      #   v2.12.0). A standalone server reports only itself, as the leader.
      #   The values are the server's: leader_since is a String, and the
      #   active of the replicas is in nanoseconds.
      #   @return [Hash]
      # @!attribute ts
      #   When the server reported this info (requires nats-server v2.10.0).
      #   @return [Time]
      StreamInfo = Struct.new(:type, :config, :created, :state, :domain,
        :mirror, :sources, :cluster, :ts,
        keyword_init: true) do
        def initialize(opts = {})
          opts[:config] = StreamConfig.new(opts[:config])
          opts[:state] = StreamState.new(opts[:state])
          opts[:created] = ::Time.parse(opts[:created])
          opts[:ts] = ::Time.parse(opts[:ts]) if opts[:ts]

          # Filter fields and freeze.
          rem = opts.keys - members
          opts.delete_if { |k| rem.include?(k) }
          super
          freeze
        end
      end

      # StreamState is the state of a stream.
      #
      # @!attribute messages
      #   @return [Integer]
      # @!attribute bytes
      #   @return [Integer]
      # @!attribute first_seq
      #   @return [Integer]
      # @!attribute last_seq
      #   @return [Integer]
      # @!attribute consumer_count
      #   @return [Integer]
      StreamState = Struct.new(:messages, :bytes, :first_seq, :first_ts,
        :last_seq, :last_ts, :consumer_count,
        keyword_init: true) do
        def initialize(opts = {})
          rem = opts.keys - members
          opts.delete_if { |k| rem.include?(k) }
          super
        end
      end

      # StreamCreateResponse is the response from the JetStream $JS.API.STREAM.CREATE API.
      #
      # @!attribute type
      #   @return [String]
      # @!attribute config
      #   @return [StreamConfig]
      # @!attribute created
      #   @return [String]
      # @!attribute state
      #   @return [StreamState]
      # @!attribute did_create
      #   @return [Boolean]
      StreamCreateResponse = Struct.new(:type, :config, :created, :state, :did_create,
        keyword_init: true) do
        def initialize(opts = {})
          rem = opts.keys - members
          opts.delete_if { |k| rem.include?(k) }
          opts[:config] = StreamConfig.new(opts[:config])
          opts[:state] = StreamState.new(opts[:state])
          super
          freeze
        end
      end

      RawStreamMsg = Struct.new(:subject, :seq, :data, :headers, keyword_init: true) do
        def initialize(opts)
          opts[:data] = Base64.decode64(opts[:data]) if opts[:data]
          if opts[:hdrs]
            header = Base64.decode64(opts[:hdrs])
            hdr = {}
            lines = header.lines
            lines.slice(1, header.size).each do |line|
              line.rstrip!
              next if line.empty?
              key, value = line.strip.split(/\s*:\s*/, 2)
              hdr[key] = value
            end
            opts[:headers] = hdr
          end

          # Filter out members not present.
          rem = opts.keys - members
          opts.delete_if { |k| rem.include?(k) }
          super
        end

        def sequence
          seq
        end
      end
    end
  end
end
