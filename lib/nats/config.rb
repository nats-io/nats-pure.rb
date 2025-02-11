# frozen_string_literal: true

module NATS
  class Config
    class Option
      module Typecast
        class << self
          def integer(value)
            if value.respond_to?(:to_i)
              value.to_i 
            else
              raise "invalid value"
            end
          end

          def string(value)
            value.to_s
          end

          def bool(value)
            %w[1 true t].include?(value.to_s.downcase)
          end
        end
      end

      def initialize(name, params, &block)
        @name = name
        @params = params
        @block = block
      end

      def value(options)
        value = typecast(hash(options) || env)
        value = block.call(value) if block

        value || default
      end

      private

      def hash(options)
        names.detect do |name|
          options[name] || options[name.to_s]
        end

        options[name]
      end

      def env
        ENV[params[:env]]
      end

      def default
        params[:default]
      end

      def typecast(value)
        Tyepecast.typecast(value, params)
      end
    end

    class << self
      def options
        @options ||= {}
      end

      def option(name, params)
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
  end
end
