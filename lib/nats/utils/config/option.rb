# frozen_string_literal: true

module NATS
  module Utils
    class Config
      class Option
        attr_reader :name, :params

        def initialize(name, params = {})
          @name = name
          @params = params
        end

        def value(value)
          value = env || params[:default] if value.nil?
          value = typecast(value) unless value.nil?

          validate(value)
          value
        end

        def to_h(value)
          value
        end

        private

        def env
          ENV[params[:env]] if params[:env]
        end

        def validate(value)
          raise EmptyError.new(self, value) if params[:required] && value.nil?
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
            raise IntegerError.new(self, value)
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

      class SymbolOption < Option
        def typecast(value)
          value&.to_sym
        end
      end

      class BoolOption < Option
        def typecast(value)
          %w[1 true t].include?(value.to_s.downcase)
        end
      end

      class DateOption < Option
        def typecast(value)
          case value
          when String
            Date.parse(value)
          when Time
            value.to_date
          when Date
            value
          else
            raise DateError.new(self, value)
          end
        end
      end

      class TimeOption < Option
        def typecast(value)
          case value
          when String
            Time.parse(value)
          when Date
            value.to_time
          when Time
            value
          else
            raise TimeError.new(self, value)
          end
        end
      end

      class IoOption < Option
        def typecast(value)
          case value
          when IO, File, Tempfile, StringIO
            value
          when String
            StringIO.new(value)
          else
            raise IoError.new(self, value)
          end
        end
      end

      class HashOption < Option
        def typecast(value)
          if value.respond_to?(:to_h)
            value.to_h
          else
            raise HashError.new(self, value)
          end
        end
      end

      # params[:of]
      class ArrayOption < Option
        def typecast(value)
          raise ArrayError.new(self, value) unless value.respond_to?(:map)

          value.map do |item|
            params[:item].value(item)
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
          if value.is_a?(Hash) || value.is_a?(Config)
            params[:config].new(value)
          else
            raise ObjectError.new(self, value)
          end
        end

        def to_h(value)
          value&.to_h
        end
      end
    end
  end
end
