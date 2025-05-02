# frozen_string_literal: true

require_relative "object/context"
require_relative "object/errors"

require_relative "object/store"
require_relative "object/operations"
require_relative "object/watcher"

require_relative "object/list"
require_relative "object/info"
require_relative "object/chunk"
require_relative "object/io"

module NATS
  class Object
    attr_reader :store, :info, :data

    def initialize(store, info, data = nil)
      @store = store
      @info = info
      @data = data
    end

    def update(meta)
      store.ops.update(self, meta)
    end

    def delete
      store.ops.delete(self)
    end

    def reload
      info = store.meta.find(@info.name)
      raise NATS::Object::ObjectNotFoundError if info.nil?

      @info = info
      self
    end

    def link?
      info.link?
    end

    def deleted?
      info.deleted
    end
  end
end
