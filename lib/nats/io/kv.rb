# frozen_string_literal: true

# Copyright 2021-2025 The NATS Authors
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

require_relative "kv/api"
require_relative "kv/bucket_status"
require_relative "kv/errors"
require_relative "kv/manager"

module NATS
  class KeyValue
    include MonitorMixin

    KV_OP = "KV-Operation"
    KV_DEL = "DEL"
    KV_PURGE = "PURGE"
    MSG_ROLLUP_SUBJECT = "sub"
    MSG_ROLLUP_ALL = "all"
    ROLLUP = "Nats-Rollup"

    VALID_BUCKET_RE = /\A[a-zA-Z0-9_-]+$/
    VALID_KEY_RE = /\A[-\/_=\.a-zA-Z0-9]+$/

    class << self
      def is_valid_key(key)
        if key.nil?
          false
        elsif key.start_with?(".") || key.end_with?(".")
          false
        elsif key !~ VALID_KEY_RE
          false
        else
          true
        end
      end
    end

    def initialize(opts = {})
      @name = opts[:name]
      @stream = opts[:stream]
      @pre = opts[:pre]
      @js = opts[:js]
      @direct = opts[:direct]
      @validate_keys = opts[:validate_keys]
    end

    # get returns the latest value for the key.
    def get(key, params = {})
      raise InvalidKeyError if @validate_keys && !KeyValue.is_valid_key(key)
      entry = nil
      begin
        entry = _get(key, params)
      rescue KeyDeletedError
        raise KeyNotFoundError
      end

      entry
    end

    def _get(key, params = {})
      msg = nil
      subject = "#{@pre}#{key}"

      msg = if params[:revision]
        @js.get_msg(@stream,
          seq: params[:revision],
          direct: @direct)
      else
        @js.get_msg(@stream,
          subject: subject,
          seq: params[:revision],
          direct: @direct)
      end

      entry = Entry.new(bucket: @name, key: key, value: msg.data, revision: msg.seq)

      if subject != msg.subject
        raise KeyNotFoundError.new(
          entry: entry,
          message: "expected '#{subject}', but got '#{msg.subject}'"
        )
      end

      if !msg.headers.nil?
        op = msg.headers[KV_OP]
        if (op == KV_DEL) || (op == KV_PURGE)
          raise KeyDeletedError.new(entry: entry, op: op)
        end
      end

      entry
    rescue NATS::JetStream::Error::NotFound
      raise KeyNotFoundError
    end
    private :_get

    # put will place the new value for the key into the store
    # and return the revision number.
    def put(key, value)
      raise InvalidKeyError if @validate_keys && !KeyValue.is_valid_key(key)

      ack = @js.publish("#{@pre}#{key}", value)
      ack.seq
    end

    # create will add the key/value pair iff it does not exist.
    def create(key, value)
      raise InvalidKeyError if @validate_keys && !KeyValue.is_valid_key(key)

      pa = nil
      begin
        pa = update(key, value, last: 0)
      rescue KeyWrongLastSequenceError => err
        # In case of attempting to recreate an already deleted key,
        # the client would get a KeyWrongLastSequenceError.  When this happens,
        # it is needed to fetch latest revision number and attempt to update.
        begin
          # NOTE: This reimplements the following behavior from Go client.
          #
          #   Since we have tombstones for DEL ops for watchers, this could be from that
          #   so we need to double check.
          #
          _get(key)

          # No exception so not a deleted key, so reraise the original KeyWrongLastSequenceError.
          # If it was deleted then the error exception will contain metadata
          # to recreate using the last revision.
          raise err
        rescue KeyDeletedError => err
          pa = update(key, value, last: err.entry.revision)
        end
      end

      pa
    end

    EXPECTED_LAST_SUBJECT_SEQUENCE = "Nats-Expected-Last-Subject-Sequence"

    # update will update the value iff the latest revision matches.
    def update(key, value, params = {})
      raise InvalidKeyError if @validate_keys && !KeyValue.is_valid_key(key)

      hdrs = {}
      last = (params[:last] ||= 0)
      hdrs[EXPECTED_LAST_SUBJECT_SEQUENCE] = last.to_s
      ack = nil
      begin
        ack = @js.publish("#{@pre}#{key}", value, header: hdrs)
      rescue NATS::JetStream::Error::APIError => err
        if err.err_code == 10071
          raise KeyWrongLastSequenceError.new(err.description)
        else
          raise err
        end
      end

      ack.seq
    end

    # delete will place a delete marker and remove all previous revisions.
    def delete(key, params = {})
      raise InvalidKeyError if @validate_keys && !KeyValue.is_valid_key(key)

      hdrs = {}
      hdrs[KV_OP] = KV_DEL
      last = (params[:last] ||= 0)
      if last > 0
        hdrs[EXPECTED_LAST_SUBJECT_SEQUENCE] = last.to_s
      end
      ack = @js.publish("#{@pre}#{key}", header: hdrs)

      ack.seq
    end

    # purge will remove the key and all revisions.
    def purge(key)
      raise InvalidKeyError if @validate_keys && !KeyValue.is_valid_key(key)

      hdrs = {}
      hdrs[KV_OP] = KV_PURGE
      hdrs[ROLLUP] = MSG_ROLLUP_SUBJECT
      @js.publish("#{@pre}#{key}", header: hdrs)
    end

    # status retrieves the status and configuration of a bucket.
    def status
      info = @js.stream_info(@stream)
      BucketStatus.new(info, @name)
    end

    Entry = Struct.new(:bucket, :key, :value, :revision, :delta, :created, :operation, keyword_init: true) do
      def initialize(opts = {})
        rem = opts.keys - members
        opts.delete_if { |k| rem.include?(k) }
        super
      end
    end

    # watch will be signaled when any key is updated.
    def watchall(params = {})
      watch(">", params)
    end

    # keys returns the keys from a KeyValue store.
    # Optionally filters the keys based on the provided filter list.
    def keys(params = {})
      params[:ignore_deletes] = true
      params[:meta_only] = true

      w = watchall(params)
      got_keys = false

      Enumerator.new do |y|
        w.each do |entry|
          break if entry.nil?
          got_keys = true
          y << entry.key
        end
        w.stop
        raise NoKeysFoundError unless got_keys
      end
    end

    # history retrieves the entries so far for a key.
    def history(key, params = {})
      params[:include_history] = true
      w = watch(key, params)
      got_keys = false

      Enumerator.new do |y|
        w.each do |entry|
          break if entry.nil?
          got_keys = true
          y << entry
        end
        w.stop
        raise NoKeysFoundError unless got_keys
      end
    end

    STATUS_HDR = "Status"
    DESC_HDR = "Description"
    CTRL_STATUS = "100"
    LAST_CONSUMER_SEQ_HDR = "Nats-Last-Consumer"
    LAST_STREAM_SEQ_HDR = "Nats-Last-Stream"
    CONSUMER_STALLED_HDR = "Nats-Consumer-Stalled"

    # watch will be signaled when a key that matches the keys
    # pattern is updated.
    # The first update after starting the watch is nil in case
    # there are no pending updates.
    def watch(keys, params = {})
      params[:meta_only] ||= false
      params[:include_history] ||= false
      params[:ignore_deletes] ||= false
      params[:idle_heartbeat] ||= 5 # seconds
      params[:inactive_threshold] ||= 5 * 60 # 5 minutes
      subject = "#{@pre}#{keys}"
      init_setup = new_cond
      init_setup_done = false
      nc = @js.nc
      watcher = KeyWatcher.new(@js)

      deliver_policy = if !(params[:include_history])
        "last_per_subject"
      end

      ordered = {
        # basic ordered consumer.
        flow_control: true,
        ack_policy: "none",
        max_deliver: 1,
        ack_wait: 22 * 3600,
        idle_heartbeat: params[:idle_heartbeat],
        num_replicas: 1,
        mem_storage: true,
        manual_ack: true,
        # watch related options.
        deliver_policy: deliver_policy,
        headers_only: params[:meta_only],
        inactive_threshold: params[:inactive_threshold]
      }

      # watch_updates callback.
      sub = @js.subscribe(subject, config: ordered) do |msg|
        synchronize do
          if !init_setup_done
            init_setup.wait(@js.opts[:timeout])
          end
        end

        # Control Message like Heartbeats and Flow Control
        status = msg.header[STATUS_HDR] unless msg.header.nil?
        if !status.nil? && status == CTRL_STATUS
          desc = msg.header[DESC_HDR]
          if desc.start_with?("Idle")
            # A watcher is active if it continues to receive Idle Heartbeat messages.
            #
            # Status: 100
            # Description: Idle Heartbeat
            # Nats-Last-Consumer: 185
            # Nats-Last-Stream: 185
            #
            watcher.synchronize { watcher._active = true }
          elsif desc.start_with?("FlowControl")
            # HMSG _INBOX.q6Y3JAFxOnNJi4QdwQnFtg 2 $JS.FC.KV_TEST.t00CunIG.GT4W 36 36
            # NATS/1.0 100 FlowControl Request
            nc.publish(msg.reply)
          end
          # Skip processing the control message
          next
        end

        # Track sequences
        meta = msg.metadata
        watcher.synchronize { watcher._active = true }
        # Track the sequences
        #
        # $JS.ACK.KV_TEST.CKRGrWpf.1.10.10.1739859923871837000.0
        #
        tokens = msg.reply.split(".")
        sseq = tokens[5]
        dseq = tokens[6]
        watcher.synchronize do
          watcher._dseq = dseq.to_i + 1
          watcher._sseq = sseq.to_i
        end

        # Keys() handling
        op = nil
        if msg.header && msg.header[KV_OP]
          op = msg.header[KV_OP]
          if params[:ignore_deletes]
            if (op == KV_PURGE) || (op == KV_DEL)
              if (meta.num_pending == 0) && !watcher._init_done
                # Push this to unblock enumerators.
                watcher._updates.push(nil)
                watcher._init_done = true
              end
              next
            end
          end
        end

        # Convert the msg into an Entry.
        key = msg.subject[@pre.size...msg.subject.size]
        entry = Entry.new(
          bucket: @name,
          key: key,
          value: msg.data,
          revision: meta.sequence.stream,
          delta: meta.num_pending,
          created: meta.timestamp,
          operation: op
        )
        watcher._updates.push(entry)

        # When there are no more updates send an empty marker
        # to signal that it is done, this will unblock iterators.
        if (meta.num_pending == 0) && !watcher._init_done
          watcher._updates.push(nil)
          watcher._init_done = true
        end
      end # end of callback
      watcher._sub = sub

      # Snapshot the deliver subject for the consumer.
      deliver_subject = sub.subject

      # Check from consumer info what is the number of messages
      # awaiting to be consumed to send the initial signal marker.
      stream_name = nil
      begin
        cinfo = sub.consumer_info
        stream_name = sub.consumer_info.stream_name

        synchronize do
          init_setup_done = true
          # If no delivered and/or pending messages, then signal
          # that this is the start.
          # The consumer subscription will start receiving messages
          # so need to check those that have already made it.
          received = sub.delivered
          init_setup.signal

          # When there are no more updates send an empty marker
          # to signal that it is done, this will unblock iterators.
          if (cinfo.num_pending == 0) && (received == 0)
            watcher._updates.push(nil)
            watcher._init_done = true
          end
        end
      rescue => err
        # cancel init
        sub.unsubscribe
        raise err
      end

      # Need to handle reconnect if missing too many heartbeats.
      hb_interval = params[:idle_heartbeat] * 2
      watcher._hb_task = Concurrent::TimerTask.new(execution_interval: hb_interval) do |task|
        task.shutdown if nc.closed?
        next unless nc.connected?

        # Wait for all idle heartbeats to be received, one of them would have
        # toggled the state of the consumer back to being active.
        active = watcher.synchronize {
          current = watcher._active
          # A heartbeat or another incoming message needs to toggle back.
          watcher._active = false
          current
        }
        if !active
          ccreq = ordered.dup
          ccreq[:deliver_policy] = "by_start_sequence"
          ccreq[:opt_start_seq] = watcher._sseq
          ccreq[:deliver_subject] = deliver_subject
          ccreq[:idle_heartbeat] = ordered[:idle_heartbeat]
          ccreq[:inactive_threshold] = ordered[:inactive_threshold]

          should_recreate = false
          begin
            # Check if the original is still present, if it is then do not recreate.
            begin
              sub.consumer_info
            rescue ::NATS::JetStream::Error::ConsumerNotFound => e
              e.stream ||= sub.jsi.stream
              e.consumer ||= sub.jsi.consumer
              @js.nc.send(:err_cb_call, @js.nc, e, sub)
              should_recreate = true
            end
            next unless should_recreate

            # Recreate consumer that went away after a restart.
            cinfo = @js.add_consumer(stream_name, ccreq)
            sub.jsi.consumer = cinfo.name
            watcher.synchronize { watcher._dseq = 1 }
          rescue => e
            # Dispatch to the error NATS client error callback.
            @js.nc.send(:err_cb_call, @js.nc, e, sub)
          end
        end
      rescue => e
        # WRN: Unexpected error
        @js.nc.send(:err_cb_call, @js.nc, e, sub)
      end
      watcher._hb_task.execute

      watcher
    end
  end

  class KeyWatcher
    include MonitorMixin
    include Enumerable
    attr_accessor :received, :pending, :_sub, :_updates, :_init_done, :_watcher_cond
    attr_accessor :_sseq, :_dseq, :_active, :_hb_task

    def initialize(js)
      super() # required to initialize monitor
      @js = js
      @_sub = nil
      @_updates = SizedQueue.new(256)
      @_init_done = false
      @pending = nil
      # Ordered consumer related
      @_dseq = 1
      @_sseq = 0
      @_cmeta = nil
      @_fcr = 0
      @_fciseq = 0
      @_active = true
      @_hb_task = nil
    end

    def stop
      @_hb_task.shutdown
      @_sub.unsubscribe
    end

    def updates(params = {})
      params[:timeout] ||= 5
      result = nil
      MonotonicTime.with_nats_timeout(params[:timeout]) do
        result = @_updates.pop(timeout: params[:timeout])
      end

      result
    end

    # Implements Enumerable.
    def each
      loop do
        result = @_updates.pop
        yield result
      end
    end

    def take(n)
      super.take(n).reject { |entry| entry.nil? }
    end
  end
end
