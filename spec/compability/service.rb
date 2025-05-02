# frozen_string_literal: true

require_relative "test"

module NATS
  class Compability
    class Service < Test
      def initialize
        @client = NATS.connect
      end

      def start(message)
        add_service
        add_endpoints

        message.respond("")
      end

      def stop(message)
        @service.stop
        message.respond("")
      end

      private

      def subject
        "tests.service.core.>"
      end

      def add_service
        @service = client.services.add(
          name: "demo",
          version: "1.0.0",
          description: "demo service",
          metadata: {workload: "cpu"}
        )

        @service.on_stats do |endpoint|
          {endpoint: endpoint.name}
        end
      end

      def add_endpoints
        group1 = @service.groups.add("g1")
        group2 = @service.groups.add("g2", queue: "group-queue")

        add_endpoint(@service, "demo-default-queue", subject: "demo.default", metadata: {key: "value"})
        add_endpoint(@service, "demo-custom-queue", subject: "demo.default", queue: "endpoint-group")

        add_endpoint(group1, "g1-parent-queue", subject: "parent.queue")
        add_endpoint(group1, "g1-custom-queue", subject: "custom.queue", queue: "endpoint-group")

        add_endpoint(group2, "g2-parent-queue", subject: "parent.queue")
        add_endpoint(group2, "g2-custom-queue", subject: "custom.queue", queue: "endpoint-group")

        @service.endpoints.add("faulty", subject: "faulty") do |msg|
          raise "handler error"
        end
      end

      def add_endpoint(parent, name, options)
        parent.endpoints.add(name, options) do |msg|
          msg.respond(msg.data)
        end
      end
    end
  end
end
