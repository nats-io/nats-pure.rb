# frozen_string_literal: true

require_relative "config/option"
require_relative "config/types"

module NATS
  module Utils
    class Config
      class << self
        def options
          @options ||= {}
        end

        def option(name, params, &block)
          options[name] = Option.new(name, params)

          attr_reader name

          if option.editable?
            define_method "#{name}=" do |value|
              instance_variable_set("@#{name}", option.value(name => value))
            end
          end
        end
      end

      def initialize(options)
        self.class.options.each do |name, option|
          instance_variable_set("@#{name}", option.value(options))
        end
      end

      def update(options)
        self.class.options.each do |name, option|
          if option.editable?
            instance_variable_set("@#{name}", option.value(options))
          end
        end
      end
    end
  end
end
