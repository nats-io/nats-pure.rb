# frozen_string_literal: true

require_relative "config/error"
require_relative "config/type"
require_relative "config/dsl"

module NATS
  module Utils
    class Config
      extend DSL

      def initialize(values)
        set(values)
      end

      def update(values)
        set(values)
      end

      private

      def set(values)
        self.class.schema.each do |name, type|
          instance_variable_set("@#{name}", type.value(values))
        end
      end
    end
  end
end
