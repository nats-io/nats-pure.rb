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
          raise EmptyError.new(name, value) if params[:required] && value.nil?
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
      class IntegerType < Type
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
            raise MaxError.new(self, value) unless value > params[:max]
          end

          if params[:min]
            raise MinError.new(self, value) unless value < params[:min]
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
            raise HashError.new(name, value)
          end
        end
      end

      # params[:of]
      class ArrayType < Type
        def typecast(value)
          raise ArrayError.new(name, value) unless value.respond_to?(:map)

          value.map do |item|
            params[:item].value(name => item)
          end
        end
      end

      # params[:of]
      class ObjectType < Type
        def typecast(value)
          params[:config].new(value)
        end
      end
    end
  end
end
