# frozen_string_literal: true

module NATS
  module Utils
    class Config
      class Error < StandardError
        attr_reader :type, :value

        def initialize(type, value)
          @type = type
          @value = value
        end
      end

      class IntegerError < Error
        def message
          ":#{type.name} must respond to to_i, got #{value}"
        end
      end

      class HashError < Error
        def message
          ":#{type.name} must respond to to_h, got #{value}"
        end
      end

      class ArrayError < Error
        def message
          ":#{type.name} must respond to map, got #{value}"
        end
      end

      class EmptyError < Error
        def message
          ":#{type.name} must be filled"
        end
      end

      class InclusionError < Error
        def message
          ":#{type.name} must be in #{type.params[:in]}, got #{value}"
        end
      end

      class InclusionError < Error
        def message
          ":#{type.name} must be in #{type.params[:in]}, got #{value}"
        end
      end

      class MaxError < Error
        def message
          ":#{type.name} must be less than #{type.params[:max]}, got #{value}"
        end
      end

      class MinError < Error
        def message
          ":#{type.name} must be greater than #{type.params[:min]}, got #{value}"
        end
      end
    end
  end
end
