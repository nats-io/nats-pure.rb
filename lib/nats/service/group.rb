# frozen_string_literal: true

module NATS
  class Service
    class Group
      attr_reader :service, :name, :subject, :queue, :groups, :endpoints

      def initialize(name:, parent:, queue:)
        Validator.validate(name: name, queue: queue)

        @name = name

        @service = parent.service
        @subject = parent.subject ? "#{parent.subject}.#{name}" : name
        @queue = queue || parent.queue

        @groups = Groups.new(self)
        @endpoints = Endpoints.new(self)
      end
    end

    class Groups < NATS::Utils::List
      def add(name, queue: nil)
        group = Group.new(
          name: name,
          queue: queue,
          parent: parent
        )

        insert(group)
        parent.service.groups.insert(group)

        group
      end
    end
  end
end
