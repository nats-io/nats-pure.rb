# frozen_string_literal: true

module NATS
  module Utils
    class Config
      class Option
        attr_reader :name, :params

        def initialize(name, params)
          @name = name
          @params = params
        end

        def value(options)
          value = fetch(options)
          value = typecast(value) unless value.nil?

          validate(value)
          value 
        end

        def to_h(value)
          value
        end

        private

        def fetch(options)
          options[name] || env || params[:default]
        end

        def env
          ENV[params[:env]] if params[:env]
        end

        def validate(value)
          raise EmptyError.new(name, value) if params[:required] && value.nil?
        end
      end

      # params[:as]
      # params[:in]
      class StringOption < Option
        def typecast(value)
          value.to_s
        end

        def validate(value)
          super
          return if value.nil?

          if params[:as]
            NATS::Utils::Validator.validate(params[:as] => value)
          end

          if params[:in]
            raise InclusionError.new(self, value) unless params[:in].include?(value)
          end
        end
      end

      # params[:in]
      # params[:max]
      # params[:min]
      class IntegerOption < Option
        def typecast(value)
          if value.respond_to?(:to_i)
            value.to_i
          else
            raise IntegerError.new(name, value)
          end
        end

        def validate(value)
          super
          return if value.nil?

          if params[:in]
            raise InclusionError.new(self, value) unless params[:in].include?(value)
          end

          if params[:max]
            raise MaxError.new(self, value) if value > params[:max]
          end

          if params[:min]
            raise MinError.new(self, value) if value < params[:min]
          end
        end
      end

      class BoolOption < Option
        def typecast(value)
          %w[1 true t].include?(value.to_s.downcase)
        end
      end

      class HashOption < Option
        def typecast(value)
          if value.respond_to?(:to_h)
            value.to_h
          else
            raise HashError.new(name, value)
          end
        end
      end

      # params[:of]
      class ArrayOption < Option
        def typecast(value)
          raise ArrayError.new(name, value) unless value.respond_to?(:map)

          value.map do |item|
            params[:item].value(name => item)
          end
        end

        def to_h(value)
          return if value.nil?

          value.map do |item|
            params[:item].to_h(item)
          end
        end
      end

      # params[:of]
      class ObjectOption < Option
        def typecast(value)
          params[:config].new(value)
        end

        def to_h(value)
          value&.to_h
        end
      end
    end
  end
end
