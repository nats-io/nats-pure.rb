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
        validate(values)

        schema.each do |name, option|
          set(option, values[name])
        end
      end

      def update(values)
        validate(values)

        values.each do |name, value|
          set(schema[name], value) if schema[name]
        end

        self
      end

      def each
        schema.each do |name, option|
          yield name, send(name)
        end
      end

      def [](name)
        send(name) if respond_to?(name)
      end

      def dig(*names)
        name = names.shift
        value = self[name]

        names.empty? ? value : value.dig(*names)
      end

      def to_hash
        schema.each_with_object({}) do |(name, option), hash|
          hash[name] = option.to_h(send(name))
        end
      end
      alias_method :attributes, :to_hash
      alias_method :to_h, :to_hash

      def to_json
        to_h.to_json
      end

      def to_s
        to_h.to_s
      end

      private

      def validate(values)
        unless values.is_a?(Hash) || values.is_a?(Config)
          raise InvalidInputError.new(values)
        end
      end

      def schema
        self.class.schema
      end

      def set(option, value)
        instance_variable_set("@#{option.name}", option.value(value))
      end
    end
  end
end
