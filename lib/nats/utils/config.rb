# frozen_string_literal: true

require_relative "config/error"
require_relative "config/option"
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

      def to_h
        self.class.schema.each_with_object({}) do |option, hash|
          hash[option.name] = option.to_h(send(option.name))
        end
      end

      def to_json
        to_h.to_json
      end

      private

      def set(values)
        self.class.schema.each do |option|
          instance_variable_set("@#{option.name}", option.value(values))
        end
      end
    end
  end
end
