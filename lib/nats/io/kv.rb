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

    def initialize(opts = {})
      @name = opts[:name]
      @stream = opts[:stream]
      @pre = opts[:pre]
      @js = opts[:js]
      @direct = opts[:direct]
    end

    # get returns the latest value for the key.
    def get(key, params = {})
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
      ack = @js.publish("#{@pre}#{key}", value)
      ack.seq
    end

    # create will add the key/value pair iff it does not exist.
    def create(key, value)
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
    def watchall(params={})
      watch(">", params)
    end

    # keys returns the keys from a KeyValue store.
    # Optionally filters the keys based on the provided filter list.
    def keys(params={})
      params[:ignore_deletes] = true
      params[:meta_only] = true
      w = watchall(params)
      got_keys = false
      keys = []

      if block_given?
        w.each do |entry|
          break if entry.nil?
          got_keys = true
          yield entry
        end
      else
        return Enumerator.new do |y|
          w.each do |entry|
            break if entry.nil?
            got_keys = true
            y << entry.key
          end
          w.stop
          raise NoKeysFoundError unless got_keys
        end
      end
      w.stop
      raise NoKeysFoundError unless got_keys

    end

    # history retrieves a list of the entries so far.
    def history(key, params={})
      params[:include_history] = true
      watcher = self.watch(key, params)
      entries = []

      watcher.each do |entry|
        break if entry.nil?
        entries.append(entry)
      end
      watcher.stop

      if entries.size == 0
        raise NoKeysFoundError
      end

      entries
    end

    # watch will be signaled when a key that matches the keys
    # pattern is updated.
    # The first update after starting the watch is nil in case
    # there are no pending updates.
    def watch(keys, params={})
      params[:meta_only] ||= false
      params[:include_history] ||= false
      params[:ignore_deletes] ||= false
      params[:idle_heartbeat] ||= 5 * 60 # 5 min
      subject = "#{@pre}#{keys}"
      init_setup = new_cond
      init_setup_done = false
      watcher = KeyWatcher.new(@js)
      
      deliver_policy = if not params[:include_history]
                         "last_per_subject"
                       end

      ordered = {
        # basic ordered consumer.
        :flow_control => true,
        :ack_policy => "none",
        :max_deliver => 1,
        :ack_wait => 22 * 3600,
        :idle_heartbeat => params[:idle_heartbeat],
        :num_replicas => 1,
        :mem_storage => true,
        :manual_ack => true,
        # watch related options.
        :deliver_policy => deliver_policy,
        :headers_only => params[:meta_only],
      }

      # watch_updates callback.
      sub = @js.subscribe(subject, config: ordered) do |msg|
        synchronize do
          if !init_setup_done
            init_setup.wait(@js.opts[:timeout])
          end
        end

        meta = msg.metadata
        op = nil
        if msg.header and msg.header[KV_OP]
          op = msg.header[KV_OP]

          # keys() uses this
          if params[:ignore_deletes]
            if op == KV_PURGE or op == KV_DEL
              if meta.num_pending == 0 and not watcher._init_done
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
                          operation: op,
                          )
        watcher._updates.push(entry)

        # When there are no more updates send an empty marker
        # to signal that it is done, this will unblock iterators.
        if meta.num_pending == 0 and (!watcher._init_done)
          watcher._updates.push(nil)
          watcher._init_done = true
        end
      end # end of callback
      watcher._sub = sub

      # Check from consumer info what is the number of messages
      # awaiting to be consumed to send the initial signal marker.
      pending = 0
      begin
        cinfo = sub.consumer_info
        pending = cinfo.num_pending

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
          if cinfo.num_pending == 0 and received == 0
            watcher._updates.push(nil)
            watcher._init_done = true
          end
        end

      rescue => err
        # cancel init
        sub.unsubscribe
        raise err
      end
      watcher
    end
  end

  class KeyWatcher
    include MonitorMixin
    include Enumerable
    attr_accessor :received, :pending, :_sub, :_updates, :_init_done, :_watcher_cond

    def initialize(js)
      @js = js
      @_sub = nil
      @_updates = SizedQueue.new(256)
      @_init_done = false
      @pending = nil
    end

    def stop
      @_sub.unsubscribe()
    end

    def updates(params={})
      params[:timeout] ||= 5
      result = nil
      MonotonicTime::with_nats_timeout(params[:timeout]) do
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
