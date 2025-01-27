# frozen_string_literal: true

module NATS
  class Service
    module Extension
      def add_group(name, queue: nil)
        group = Group.new(
          name: name,
          queue: queue,
          parent: self
        )

        service.groups << group
        group
      end

      def add_endpoint(name, options = {}, &block)
        endpoint = Endpoint.new(
          name: name,
          options: options,
          parent: self,
          &block
        )

        service.endpoints << endpoint
        endpoint
      end
    end
  end
end
