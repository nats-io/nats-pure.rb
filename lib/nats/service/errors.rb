# frozen_string_literal: true

module NATS
  class Service
    class Error < StandardError; end

    class InvalidNameError < Error; end

    class InvalidVersionError < Error; end

    class InvalidQueueError < Error; end

    class InvalidSubjectError < Error; end
  end
end
