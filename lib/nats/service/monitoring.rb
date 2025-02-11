# frozen_string_literal: true

require "json"

module NATS
  class Service
    class Monitoring
      DEFAULT_PREFIX = "$SRV"

      VERBS = {
        ping: "PING",
        info: "INFO",
        stats: "STATS"
      }.freeze

      TYPES = {
        ping: "io.nats.micro.v1.ping_response",
        info: "io.nats.micro.v1.info_response",
        stats: "io.nats.micro.v1.stats_response"
      }.freeze

      attr_reader :service, :prefix, :stopped

      def initialize(service, prefix = nil)
        @service = service
        @prefix = prefix || DEFAULT_PREFIX

        setup_monitors
      end

      def stop
        return if @monitors.nil?

        @monitors.each do |monitor|
          service.client.send(:drain_sub, monitor)
        end
      rescue
        # nothing we can do here
      ensure
        @monitors = nil
      end

      def stopped?
        @monitors.nil?
      end

      private

      def setup_monitors
        @monitors = []

        ping
        info
        stats
      end

      def ping
        monitor(:ping) do
          {
            type: TYPES[:ping],
            **service.status.basic
          }
        end
      end

      def info
        monitor(:info) do
          {
            type: TYPES[:info],
            **service.status.info
          }
        end
      end

      def stats
        monitor(:stats) do
          {
            type: TYPES[:stats],
            **service.status.stats
          }
        end
      end

      def monitor(verb, &block)
        subjects(verb).map do |subject|
          @monitors << subscribe_monitor(subject, block)
        end
      end

      def subscribe_monitor(subject, block)
        service.client.subscribe(subject) do |message|
          message.respond(block.call.to_json)
        end
      rescue => error
        service.stop(error)
        raise error
      end

      def subjects(verb)
        [
          "#{prefix}.#{VERBS[verb]}",
          "#{prefix}.#{VERBS[verb]}.#{service.name}",
          "#{prefix}.#{VERBS[verb]}.#{service.name}.#{service.id}"
        ]
      end
    end
  end
end
