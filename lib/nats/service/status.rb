# frozen_string_literal: true

module NATS
  class Service
    class Status
      attr_reader :service, :started_at

      def initialize(service)
        @service = service
        @started_at = Time.now
      end

      def basic
        {
          name: service.name,
          id: service.id,
          version: service.version,
          metadata: service.metadata
        }
      end

      def info
        {
          **basic,
          description: service.description,
          endpoints: service.endpoints.map do |endpoint|
            {
              name: endpoint.name,
              subject: endpoint.subject,
              queue_group: endpoint.queue,
              metadata: endpoint.metadata
            }
          end
        }
      end

      def stats
        {
          **basic,
          started: started_at.utc.iso8601,
          endpoints: service.endpoints.map do |endpoint|
            endpoint_stats(endpoint)
          end
        }
      end

      private

      def endpoint_stats(endpoint)
        endpoint.stats.synchronize do
          {
            name: endpoint.name,
            subject: endpoint.subject,
            queue_group: endpoint.queue,
            num_requests: endpoint.stats.num_requests,
            processing_time: endpoint.stats.processing_time,
            average_processing_time: endpoint.stats.average_processing_time,
            num_errors: endpoint.stats.num_errors,
            last_error: endpoint.stats.last_error,
            data: service.callbacks.call(:stats, endpoint)
          }
        end
      end
    end
  end
end
