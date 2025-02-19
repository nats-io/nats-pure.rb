# frozen_string_literal: true

require_relative "config/error"
require_relative "config/option"
require_relative "config/dsl"

module NATS
  module Utils
    class Config
      include Enumerable
      extend DSL

      def initialize(values)
        schema.each do |name, option|
          set(option, values[name])
        end
      end

      def update(values)
        values.each do |name, value|
          set(schema[name], value)
        end
      end

      def each
        schema.each do |name, option|
          yield name, send(name)
        end
      end

      def [](name)
        send(name)
      end

      def to_h
        schema.each_with_object({}) do |(name, option), hash|
          hash[name] = option.to_h(send(name))
        end
      end

      def to_json
        to_h.to_json
      end

      private

      def schema
        self.class.schema
      end

      def set(option, value)
        instance_variable_set("@#{option.name}", option.value(value))
      end
    end
  end
end
