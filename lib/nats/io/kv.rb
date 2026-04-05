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
      nc = @js.nc
      watcher = KeyWatcher.new(@js)

      deliver_policy = if !(params[:include_history])
        "last_per_subject"
      end

      consumer_config = {
        ack_policy: "none",
        ack_wait: 22 * 3600,
        deliver_policy: deliver_policy,
        headers_only: params[:meta_only],
        inactive_threshold: params[:inactive_threshold],
        replay_policy: "instant",
        mem_storage: true,
        num_replicas: 1
      }

      # Create a pull consumer with a generated name.
      consumer_name = "_KV_WATCH_#{SecureRandom.hex(8)}"
      sub = @js.pull_subscribe(subject, consumer_name, config: consumer_config)
      watcher._sub = sub
      watcher._pull_sub = sub

      # Check initial state to detect empty bucket.
      stream_name = sub.jsi.stream
      initial_pending = 0
      begin
        cinfo = sub.consumer_info
        initial_pending = cinfo.num_pending
        if initial_pending == 0
          watcher._updates.push(nil)
          watcher._init_done = true
        end
      rescue => err
        sub.unsubscribe
        raise err
      end

      # Fetch loop configuration.
      max_batch_size = 256
      idle_heartbeat = params[:idle_heartbeat]
      ignore_deletes = params[:ignore_deletes]
      pre = @pre
      bucket_name = @name

      # Single background thread that fetches messages and pushes entries to _updates.
      watcher._fetch_thread = Thread.new do
        remaining = initial_pending
        while !watcher._done
          begin
            if watcher._init_done
              msgs = sub.fetch(1, timeout: idle_heartbeat)
            else
              # Size batch to what we know is pending, capped at max_batch_size.
              # Use a short timeout during catchup since fetch() always makes
              # a second wait-request after the no_wait batch completes.
              batch = [[remaining, 1].max, max_batch_size].min
              msgs = sub.fetch(batch, timeout: 1)
            end

            msgs.each do |msg|
              # Skip status/control messages.
              next if msg.header && msg.header[STATUS_HDR]

              meta = msg.metadata
              watcher.synchronize do
                watcher._active = true
                watcher._sseq = meta.sequence.stream
                watcher._dseq = meta.sequence.consumer
              end

              # Handle deletes/purges.
              op = nil
              if msg.header && msg.header[KV_OP]
                op = msg.header[KV_OP]
                if ignore_deletes
                  if (op == KV_PURGE) || (op == KV_DEL)
                    if (meta.num_pending == 0) && !watcher._init_done
                      watcher._updates.push(nil)
                      watcher._init_done = true
                    end
                    next
                  end
                end
              end

              # Convert the msg into an Entry.
              key = msg.subject[pre.size...msg.subject.size]
              entry = Entry.new(
                bucket: bucket_name,
                key: key,
                value: msg.data,
                revision: meta.sequence.stream,
                delta: meta.num_pending,
                created: meta.timestamp,
                operation: op
              )
              watcher._updates.push(entry)

              # Track remaining for batch sizing during catchup.
              remaining = meta.num_pending

              # When there are no more updates send an empty marker
              # to signal that it is done, this will unblock iterators.
              if (meta.num_pending == 0) && !watcher._init_done
                watcher._updates.push(nil)
                watcher._init_done = true
              end
            end
          rescue NATS::Timeout
            # Normal when no new messages; just retry.
            next
          rescue => e
            # Consumer may be gone (server restart). Attempt recreation.
            next if watcher._done
            begin
              # Wait for reconnection.
              sleep 1 until nc.connected? || watcher._done
              next if watcher._done

              # Check if consumer still exists.
              begin
                sub.consumer_info
                next # Consumer still alive, transient error.
              rescue ::NATS::JetStream::Error::ConsumerNotFound => cnf
                cnf.stream ||= sub.jsi.stream
                cnf.consumer ||= sub.jsi.consumer
                nc.send(:err_cb_call, nc, cnf, sub)
              end

              # Recreate consumer with resume from last known sequence.
              recreate_config = consumer_config.dup
              recreate_config[:deliver_policy] = "by_start_sequence"
              recreate_config[:opt_start_seq] = watcher._sseq + 1
              cinfo = @js.add_consumer(stream_name, recreate_config)
              sub.jsi.consumer = cinfo.name
              # Update the next message subject for the new consumer.
              sub.jsi.nms = "#{@js.instance_variable_get(:@prefix)}.CONSUMER.MSG.NEXT.#{stream_name}.#{cinfo.name}"
              watcher.synchronize { watcher._dseq = 1 }
            rescue => reconnect_err
              nc.send(:err_cb_call, nc, reconnect_err, sub) rescue nil
              sleep 1 unless watcher._done
            end
          end
        end
      end
      watcher._fetch_thread.abort_on_exception = false

      # Watchdog timer to detect fetch thread death and trigger reconnection.
      hb_interval = params[:idle_heartbeat] * 2
      watcher._hb_task = Concurrent::TimerTask.new(execution_interval: hb_interval) do |task|
        task.shutdown if nc.closed? || watcher._done
        next unless nc.connected?

        # Check if fetch thread is still alive.
        unless watcher._fetch_thread&.alive?
          next if watcher._done
          nc.send(:err_cb_call, nc, ::NATS::JetStream::Error.new("nats: kv watch fetch thread died"), sub) rescue nil
        end
      rescue => e
        nc.send(:err_cb_call, nc, e, sub) rescue nil
      end
      watcher._hb_task.execute

      watcher
    end
  end

  class KeyWatcher
    include MonitorMixin
    include Enumerable
    attr_accessor :received, :pending, :_sub, :_pull_sub, :_updates, :_init_done
    attr_accessor :_sseq, :_dseq, :_active, :_hb_task, :_fetch_thread, :_done

    def initialize(js)
      super() # required to initialize monitor
      @js = js
      @_sub = nil
      @_pull_sub = nil
      @_updates = SizedQueue.new(256)
      @_init_done = false
      @_done = false
      @pending = nil
      @_dseq = 1
      @_sseq = 0
      @_active = true
      @_hb_task = nil
      @_fetch_thread = nil
    end

    def stop
      @_done = true
      @_hb_task&.shutdown
      @_sub&.unsubscribe
      # Fetch thread may be blocked in sub.fetch(); give it a brief
      # chance to exit cleanly, then kill it.
      if @_fetch_thread && !@_fetch_thread.join(0.1)
        @_fetch_thread.kill
      end
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
