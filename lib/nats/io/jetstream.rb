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
require_relative "kv"
require_relative "jetstream/api"
require_relative "jetstream/errors"
require_relative "jetstream/js"
require_relative "jetstream/manager"
require_relative "jetstream/msg"
require_relative "jetstream/pull_subscription"
require_relative "jetstream/push_subscription"

module NATS
  # JetStream returns a context with a similar API as the NATS::Client
  # but with enhanced functions to persist and consume messages from
  # the NATS JetStream engine.
  #
  # @example
  #   nc = NATS.connect("demo.nats.io")
  #   js = nc.jetstream()
  #
  class JetStream
    # Create a new JetStream context for a NATS connection.
    #
    # @param conn [NATS::Client]
    # @param params [Hash] Options to customize JetStream context.
    # @option params [String] :prefix JetStream API prefix to use for the requests.
    # @option params [String] :domain JetStream Domain to use for the requests.
    # @option params [Float] :timeout Default timeout to use for JS requests.
    def initialize(conn, params = {})
      @nc = conn
      @prefix = if params[:prefix]
        params[:prefix]
      elsif params[:domain]
        "$JS.#{params[:domain]}.API"
      else
        JS::DefaultAPIPrefix
      end
      @opts = params
      @opts[:timeout] ||= 5 # seconds
      params[:prefix] = @prefix

      # Include JetStream::Manager
      extend Manager
      extend KeyValue::Manager
    end

    # PubAck is the API response from a successfully published message.
    #
    # @!attribute [stream] stream
    #   @return [String] Name of the stream that processed the published message.
    # @!attribute [seq] seq
    #   @return [Fixnum] Sequence of the message in the stream.
    # @!attribute [duplicate] duplicate
    #   @return [Boolean] Indicates whether the published message is a duplicate.
    # @!attribute [domain] domain
    #   @return [String] JetStream Domain that processed the ack response.
    PubAck = Struct.new(:stream, :seq, :duplicate, :domain, keyword_init: true)

    # publish produces a message for JetStream.
    #
    # @param subject [String] The subject from a stream where the message will be sent.
    # @param payload [String] The payload of the message.
    # @param params [Hash] Options to customize the publish message request.
    # @option params [Float] :timeout Time to wait for an PubAck response or an error.
    # @option params [Hash] :header NATS Headers to use for the message.
    # @option params [String] :stream Expected Stream to which the message is being published.
    # @raise [NATS::Timeout] When it takes too long to receive an ack response.
    # @return [PubAck] The pub ack response.
    def publish(subject, payload = "", **params)
      params[:timeout] ||= @opts[:timeout]
      if params[:stream]
        params[:header] ||= {}
        params[:header][JS::Header::ExpectedStream] = params[:stream]
      end

      # Send message with headers.
      msg = NATS::Msg.new(subject: subject,
        data: payload,
        header: params[:header])

      begin
        resp = @nc.request_msg(msg, **params)
        result = JSON.parse(resp.data, symbolize_names: true)
      rescue ::NATS::IO::NoRespondersError
        raise JetStream::Error::NoStreamResponse.new("nats: no response from stream")
      end
      raise JS.from_error(result[:error]) if result[:error]

      PubAck.new(result)
    end

    # subscribe binds or creates a push subscription to a JetStream pull consumer.
    #
    # @param subject [String, Array] Subject(s) from which the messages will be fetched.
    # @param params [Hash] Options to customize the PushSubscription.
    # @option params [String] :stream Name of the Stream to which the consumer belongs.
    # @option params [String] :consumer Name of the Consumer to which the PushSubscription will be bound.
    # @option params [String] :name Name of the Consumer to which the PushSubscription will be bound.
    # @option params [String] :durable Consumer durable name from where the messages will be fetched.
    # @option params [Hash] :config Configuration for the consumer.
    # @return [NATS::JetStream::PushSubscription]
    def subscribe(subject, params = {}, &cb)
      params[:consumer] ||= params[:durable]
      params[:consumer] ||= params[:name]
      multi_filter = if subject.is_a?(Array) && (subject.size == 1)
        subject = subject.first
        false
      elsif subject.is_a?(Array) && (subject.size > 1)
        true
      end

      stream = if params[:stream].nil?
        if multi_filter
          # Use the first subject to try to find the stream.
          streams = subject.map do |s|
            find_stream_name_by_subject(s)
          rescue NATS::JetStream::Error::NotFound
            raise NATS::JetStream::Error.new("nats: could not find stream matching filter subject '#{s}'")
          end

          # Ensure that the filter subjects are not ambiguous.
          streams.uniq!
          if streams.count > 1
            raise NATS::JetStream::Error.new("nats: multiple streams matched filter subjects: #{streams}")
          end

          streams.first
        else
          find_stream_name_by_subject(subject)
        end
      else
        params[:stream]
      end

      queue = params[:queue]
      durable = params[:durable]
      params[:flow_control]
      manual_ack = params[:manual_ack]
      idle_heartbeat = params[:idle_heartbeat]
      flow_control = params[:flow_control]
      config = params[:config]

      if queue
        if durable && (durable != queue)
          raise NATS::JetStream::Error.new("nats: cannot create queue subscription '#{queue}' to consumer '#{durable}'")
        else
          durable = queue
        end
      end

      cinfo = nil
      consumer_found = false
      should_create = false

      if !durable
        should_create = true
      else
        begin
          cinfo = consumer_info(stream, durable)
          config = cinfo.config
          consumer_found = true
          consumer = durable
        rescue NATS::JetStream::Error::NotFound
          should_create = true
          consumer_found = false
        end
      end

      if consumer_found
        if !config.deliver_group
          if queue
            raise NATS::JetStream::Error.new("nats: cannot create a queue subscription for a consumer without a deliver group")
          elsif cinfo.push_bound
            raise NATS::JetStream::Error.new("nats: consumer is already bound to a subscription")
          end
        elsif !queue
          raise NATS::JetStream::Error.new("nats: cannot create a subscription for a consumer with a deliver group #{config.deliver_group}")
        elsif queue != config.deliver_group
          raise NATS::JetStream::Error.new("nats: cannot create a queue subscription #{queue} for a consumer with a deliver group #{config.deliver_group}")
        end
      elsif should_create
        # Auto-create consumer if none found.
        if config.nil?
          # Defaults
          config = JetStream::API::ConsumerConfig.new({ack_policy: "explicit"})
        elsif config.is_a?(Hash)
          config = JetStream::API::ConsumerConfig.new(config)
        elsif !config.is_a?(JetStream::API::ConsumerConfig)
          raise NATS::JetStream::Error.new("nats: invalid ConsumerConfig")
        end

        config.durable_name = durable if !config.durable_name
        config.deliver_group = queue if !config.deliver_group

        # Create inbox for push consumer.
        deliver = @nc.new_inbox
        config.deliver_subject = deliver

        # Auto created consumers use the filter subject.
        if multi_filter
          config[:filter_subjects] ||= subject
        else
          config[:filter_subject] ||= subject
        end

        # Heartbeats / FlowControl
        config.flow_control = flow_control
        if idle_heartbeat || config.idle_heartbeat
          idle_heartbeat = config.idle_heartbeat if config.idle_heartbeat
          idle_heartbeat *= ::NATS::NANOSECONDS
          config.idle_heartbeat = idle_heartbeat
        end

        # Auto create the consumer.
        cinfo = add_consumer(stream, config)
        consumer = cinfo.name
      end

      # Enable auto acking for async callbacks unless disabled.
      if cb && !manual_ack
        ocb = cb
        new_cb = proc do |msg|
          ocb.call(msg)
          begin
            msg.ack
          rescue
            JetStream::Error::MsgAlreadyAckd
          end
        end
        cb = new_cb
      end
      sub = @nc.subscribe(config.deliver_subject, queue: config.deliver_group, &cb)
      sub.extend(PushSubscription)
      sub.jsi = JS::Sub.new(
        js: self,
        stream: stream,
        consumer: consumer
      )
      sub
    end

    # pull_subscribe binds or creates a subscription to a JetStream pull consumer.
    #
    # @param subject [String, Array] Subject or subjects from which the messages will be fetched.
    # @param durable [String] Consumer durable name from where the messages will be fetched.
    # @param params [Hash] Options to customize the PullSubscription.
    # @option params [String] :stream Name of the Stream to which the consumer belongs.
    # @option params [String] :consumer Name of the Consumer to which the PullSubscription will be bound.
    # @option params [String] :name Name of the Consumer to which the PullSubscription will be bound.
    # @option params [Hash] :config Configuration for the consumer.
    # @return [NATS::JetStream::PullSubscription]
    def pull_subscribe(subject, durable, params = {})
      if (!durable || durable.empty?) && !(params[:consumer] || params[:name])
        raise JetStream::Error::InvalidDurableName.new("nats: invalid durable name")
      end
      multi_filter = if subject.is_a?(Array) && (subject.size == 1)
        subject = subject.first
        false
      elsif subject.is_a?(Array) && (subject.size > 1)
        true
      end

      params[:consumer] ||= durable
      params[:consumer] ||= params[:name]
      stream = if params[:stream].nil?
        if multi_filter
          # Use the first subject to try to find the stream.
          streams = subject.map do |s|
            find_stream_name_by_subject(s)
          rescue NATS::JetStream::Error::NotFound
            raise NATS::JetStream::Error.new("nats: could not find stream matching filter subject '#{s}'")
          end

          # Ensure that the filter subjects are not ambiguous.
          streams.uniq!
          if streams.count > 1
            raise NATS::JetStream::Error.new("nats: multiple streams matched filter subjects: #{streams}")
          end

          streams.first
        else
          find_stream_name_by_subject(subject)
        end
      else
        params[:stream]
      end
      begin
        consumer_info(stream, params[:consumer])
      rescue NATS::JetStream::Error::NotFound => e
        # If attempting to bind, then this is a hard error.
        raise e if params[:stream] && !multi_filter

        config = if !(params[:config])
          JetStream::API::ConsumerConfig.new
        elsif params[:config].is_a?(JetStream::API::ConsumerConfig)
          params[:config]
        else
          JetStream::API::ConsumerConfig.new(params[:config])
        end
        config[:durable_name] = durable
        config[:ack_policy] ||= JS::Config::AckExplicit
        if multi_filter
          config[:filter_subjects] ||= subject
        else
          config[:filter_subject] ||= subject
        end
        add_consumer(stream, config)
      end

      deliver = @nc.new_inbox
      sub = @nc.subscribe(deliver)
      sub.extend(PullSubscription)

      consumer = params[:consumer]
      subject = "#{@prefix}.CONSUMER.MSG.NEXT.#{stream}.#{consumer}"
      sub.jsi = JS::Sub.new(
        js: self,
        stream: stream,
        consumer: params[:consumer],
        nms: subject
      )
      sub
    end
  end
end
