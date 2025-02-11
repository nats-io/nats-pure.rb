# frozen_string_literal: true

module NATS
  class Service
    class Endpoint
      attr_reader :name, :service, :subject, :metadata, :queue, :stats

      def initialize(name:, options:, parent:, &block)
        validate(name, options)

        @name = name

        @service = parent.service
        @subject = build_subject(parent, options)
        @queue = options[:queue] || parent.queue
        @metadata = options[:metadata]

        @stats = NATS::Service::Stats.new
        @handler = create_handler(block)

        @stopped = false
      end

      def stop
        service.client.send(:drain_sub, @handler)
      rescue
        # nothing we can do here
      ensure
        @stopped = true
      end

      def reset
        stats.reset
      end

      def stopped?
        @stopped
      end

      private

      def validate(name, options)
        Validator.validate(
          name: name,
          subject: options[:subject],
          queue: options[:queue]
        )
      end

      def build_subject(parent, options)
        subject = options[:subject] || name

        parent.subject ? "#{parent.subject}.#{subject}" : subject
      end

      def create_handler(block)
        service.client.subscribe(subject, queue: queue) do |msg|
          started_at = Time.now

          block.call(msg)
          stats.error(msg.error) if msg.error
        rescue NATS::Error => error
          stats.error(error)
          service.stop(error)

          raise error
        rescue => error
          stats.error(error)
          msg.respond_with_error(error)
        ensure
          stats.record(started_at)
        end
      rescue => error
        service.stop(error)
        raise error
      end
    end

    class Endpoints < NATS::Utils::List
      def add(name, options = {}, &block)
        endpoint = Endpoint.new(
          name: name,
          options: options,
          parent: parent,
          &block
        )

        insert(endpoint)
        parent.service.endpoints.insert(endpoint)

        endpoint
      end
    end
  end
end
