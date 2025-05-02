# frozen_string_literal: true

require_relative "store/config"
require_relative "store/status"

require_relative "store/list"

require_relative "store/subject"
require_relative "store/meta"
require_relative "store/chunks"

module NATS
  class Object
    class Store
      attr_reader :context, :stream, :config
      attr_reader :nuid, :ops, :meta, :chunks

      def initialize(context, stream, config)
        @context = context
        @stream = stream

        @config = Config.new(config)
        @nuid = NATS::NUID.new

        @ops = Operations.new(self)
        @meta = Meta.new(self)
        @chunks = Chunks.new(self)
      end

      def status
        Status.new(self)
      end

      def put(meta)
        ops.put(meta)
      end

      def get(name, options = {})
        ops.get(name, options)
      end

      def link(name:, to:)
        ops.link(name, to)
      end

      def update(config)
        @config.update(config)
        stream.update(@config.stream)

        self
      rescue NATS::JetStream::StreamNotFoundError
        raise NATS::Object::StoreNotFoundError
      end

      def seal
        stream.update(sealed: true)
      rescue NATS::JetStream::ServerError
        raise NATS::Object::StoreSealedError
      end

      def sealed?
        status.sealed
      rescue NATS::JetStream::StreamNotFoundError
        raise NATS::Object::StoreNotFoundError
      end

      def delete
        stream.delete
      rescue NATS::JetStream::StreamNotFoundError
        raise NATS::Object::StoreNotFoundError
      end

      def deleted?
        !stream.info
      rescue NATS::JetStream::StreamNotFoundError
        true
      end

      def watch(options = {})
        Watcher.new(self, options)
      end

      def objects(options = {})
        Object::List.new(self, options)
      end
    end
  end
end
