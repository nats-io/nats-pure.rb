# frozen_string_literal: true

module NATS
  module Utils
    class Error < StandardError
      # Since service validator and its errors
      # were moved under NATS::Utils, this method
      # transforms NATS::Utils errors into NATS::Service
      # errors to make services errors backward compatible
      def to_service_error
        case self
        when NATS::Utils::InvalidNameError
          NATS::Service::InvalidNameError
        when NATS::Utils::InvalidVersionError
          NATS::Service::InvalidVersionError
        when NATS::Utils::InvalidQueueError
          NATS::Service::InvalidQueueError
        when NATS::Utils::InvalidSubjectError
          NATS::Service::InvalidSubjectError
        end
      end
    end

    class InvalidNameError < Error; end

    class InvalidVersionError < Error; end

    class InvalidQueueError < Error; end

    class InvalidSubjectError < Error; end
  end
end
