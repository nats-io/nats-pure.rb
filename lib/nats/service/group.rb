# frozen_string_literal: true

module NATS
  class Service
    class Group
      include Extension

      attr_reader :service, :name, :subject, :queue

      def initialize(name:, parent:, queue:)
        Validator.validate(name: name, queue: queue)

        @name = name

        @service = parent.service
        @subject = parent.subject ? "#{parent.subject}.#{name}" : name
        @queue = queue || parent.queue
      end
    end
  end
end
