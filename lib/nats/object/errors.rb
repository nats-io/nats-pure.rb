# frozen_string_literal: true

module NATS
  class Object
    class Error < NATS::IO::Error; end

    class StoreNotFoundError < Error; end

    class StoreSealedError < Error; end

    class ObjectNotFoundError < Error; end

    class ObjectDeletedError < Error; end

    class ObjectExistsError < Error; end

    class NoLinkToLinkError < Error; end

    class NotLinkError < Error; end

    class NameTakenError < Error; end

    class InvalidDigestError < Error; end

    class DigestMismatchError < Error; end
  end
end
