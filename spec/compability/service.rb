# frozen_string_literal: true

module NATS
  class Compability
    class ServiceApi
      class Service
        attr_reader :service, :client

        def initialize(client)
          @client = client
        end

        def start
          add_service
          add_endpoints
        end

        def stop
          @service.stop
        end

        private

        def add_service
          @service = client.add_service(
            name: "demo",
            version: "1.0.0",
            description: "demo service",
            metadata: {workload: "cpu"}
          )

          service.on_stats do |endpoint|
            {endpoint: endpoint.name}
          end
        end

        def add_endpoints
          group1 = service.add_group("g1")
          group2 = service.add_group("g2", queue: "group-queue")

          add_endpoint(service, "demo-default-queue", subject: "demo.default", metadata: {key: "value"})
          add_endpoint(service, "demo-custom-queue", subject: "demo.default", queue: "endpoint-group")

          add_endpoint(group1, "g1-parent-queue", subject: "parent.queue")
          add_endpoint(group1, "g1-custom-queue", subject: "custom.queue", queue: "endpoint-group")

          add_endpoint(group2, "g2-parent-queue", subject: "parent.queue")
          add_endpoint(group2, "g2-custom-queue", subject: "custom.queue", queue: "endpoint-group")

          service.add_endpoint("faulty", subject: "faulty") do |msg|
            raise "handler error"
          end
        end

        def add_endpoint(parent, name, options)
          parent.add_endpoint(name, options) do |msg|
            msg.respond(msg.data)
          end
        end
      end

      def run
        service = Service.new(client)

        client.subscribe("tests.service.core.>") do |msg|
          if msg.data.empty?
            service.stop
          else
            service.start
          end

          msg.respond("")
        end
      end

      def client
        @client ||= NATS.connect
      end
    end
  end
end
