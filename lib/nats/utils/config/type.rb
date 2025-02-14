# frozen_string_literal: true

module NATS
  module Utils
    class Config
      class Type
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

        private

        def fetch(options)
          options[name] || env || params[:default]
        end

        def validate(value)
          raise "" if params[:required] && value.nil?
        end

        def env
          ENV[params[:env]] if params[:env]
        end
      end

      # params[:as]
      # params[:in]
      class StringType < Type
        def typecast(value)
          value.to_s
        end

        def validate(value)
          raise "" if params[:required] && value.nil?
          return if value.nil?

          if params[:as]
            NATS::Utils::Validator.validate(params[:as] => value)
          end

          if params[:in]
            raise "" unless params[:in].include?(value)
          end
        end
      end

      # params[:in]
      # params[:max]
      # params[:min]
      class IntegerType < Type
        def typecast(value)
          if value.respond_to?(:to_i)
            value.to_i
          else
            raise "invalid value"
          end
        end

        def validate(value)
          raise "" if params[:required] && value.nil?
          return if value.nil?

          if params[:in]
            raise "" unless params[:in].include?(value)
          end

          if params[:max]
            raise "" unless value > params[:max]
          end

          if params[:min]
            raise "" unless value < params[:min]
          end
        end
      end

      class BoolType < Type
        def typecast(value)
          %w[1 true t].include?(value.to_s.downcase)
        end
      end

      class HashType < Type
        def typecast(value)
          if value.respond_to?(:to_h)
            value.to_h
          else
            raise "invalid value"
          end
        end
      end

      # params[:of]
      class ArrayType < Type
        def typecast(values)
          raise "" unless values.respond_to?(:map)

          values.map do |value|
            params[:of].value(value)
          end
        end
      end

      # params[:of]
      class ObjectType < Type
        def typecast(value)
          params[:of].new(value)
        end
      end
    end
  end
end
