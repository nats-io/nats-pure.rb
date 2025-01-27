# frozen_string_literal: true

module NATS
  class Service
    class Callbacks
      attr_reader :service, :callbacks

      def initialize(service)
        @service = service
        @callbacks = {}
      end

      def register(name, &block)
        callbacks[name] = block
      end

      def call(name, *args)
        callbacks[name]&.call(*args)
      end
    end
  end
end
