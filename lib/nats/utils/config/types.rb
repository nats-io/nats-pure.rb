# frozen_string_literal: true

require "singleton"

module NATS
  module Utils
    class Config
      class Type
        include Singleton

        def value(value)
          validate(typecast(value))
        end

        def typecast(value)
        end

        def validate(value)
        end
      end

      class StringType < Type
        def typecast(value)
          value.to_s
        end
      end

      class IntegerType < Type
        def typecast(value)
          if value.respond_to?(:to_i)
            value.to_i
          else
            raise "invalid value"
          end
        end
      end

      class BoolType < Type
        def typecast(value)
          %w[1 true t].include?(value.to_s.downcase)
        end
      end

      class ArrayType < Type
        class << self
          attr_reader :item_type

          def [](type)
            @item_type = type
          end
        end

        def typecast(value)
        end
      end

      class NominalType < StringType
        class << self
          attr_reader :values

          def [](*values)
            Class.new(self) do
              @values = values.freeze
            end
          end
        end

        def validate(value)
          VALUES.include?(value)
        end
      end
    end
  end
end
