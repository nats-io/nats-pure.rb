# frozen_string_literal: true

# Copyright 2025 The NATS Authors
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

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
        Utils::Validator.validate(
          name: name,
          subject: options[:subject],
          queue: options[:queue]
        )
      rescue NATS::Utils::Error => error
        raise error.to_service_error
      end

      def build_subject(parent, options)
        subject = options[:subject] || name

        parent.subject ? "#{parent.subject}.#{subject}" : subject
      end

      def create_handler(block)
        service.client.subscribe(subject, queue: queue) do |message|
          started_at = Time.now

          message = Message.new(service, message)
          block.call(message)
          stats.error(message.error) if message.error?
        rescue NATS::Error => error
          stats.error(error)
          service.stop(error)

          raise error
        rescue => error
          stats.error(error)
          Message.new(service, message).respond_with_error(error)
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
