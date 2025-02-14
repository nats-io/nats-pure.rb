# frozen_string_literal: true

module NATS
  module Utils
    class Config
      module DSL
        def schema
          @schema ||= {}
        end

        def types
          @types ||= {
            string: StringType,
            integer: IntegerType,
            bool: BoolType,
            array: ArrayType,
            hash: HashType
          }
        end

        def string(name, params = {})
          register(StringType.new(name, params))
        end

        def integer(name, params = {})
          register(IntegerType.new(name, params))
        end

        def bool(name, params = {})
          register(BoolType.new(name, params))
        end

        def array(name, params = {}, &block)
          params[:of] = types[params[:of]] if params[:of]
          params[:of] = type(name, &block) if block

          register(ArrayType.new(name, params))
        end

        def hash(name, params = {})
          register(HashType.new(name, params))
        end

        def object(name, params = {}, &block)
          params[:of] = types[params[:of]] if params[:of]
          params[:of] = type(name, &block) if block

          register(ObjectType.new(name, params))
        end

        def type(name, &block)
          type = Class.new(Config)
          type.class_eval(&block)

          types[name] = type
        end

        private

        def register(type)
          schema[type.name] = type
          attr_reader type.name
        end
      end
    end
  end
end
