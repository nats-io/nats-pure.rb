# frozen_string_literal: true

module NATS
  module Utils
    class Config
      module DSL
        attr_accessor :configs

        TYPES = {
          string: NATS::Utils::Config::StringType,
          integer: NATS::Utils::Config::IntegerType,
          bool: NATS::Utils::Config::BoolType,
          hash: NATS::Utils::Config::HashType,
          array: NATS::Utils::Config::ArrayType,
          object: NATS::Utils::Config::ObjectType
        }.freeze

        def schema
          @schema ||= {}
        end

        def configs
          @configs ||= {}
        end

        def string(name, params = {})
          register(:string, name, params)
        end

        def integer(name, params = {})
          register(:integer, name, params)
        end

        def bool(name, params = {})
          register(:bool, name, params)
        end

        def hash(name, params = {})
          register(:hash, name, params)
        end

        def array(name, params = {}, &block)
          config(name, &block) if block
          config = configs[params[:of] || name]

          if config
            params[:item] = ObjectType.new(name, config: config)
          else
            params[:item] = TYPES[params[:of]].new(name, params)
          end

          register(:array, name, params)
        end

        def object(name, params = {}, &block)
          config(name, &block) if block
          params[:config] = configs[params[:of] || name]

          register(:object, name, params)
        end

        def config(name, &block)
          config = Class.new(Config)
          config.configs = configs
          config.class_eval(&block)

          configs[name] = config
        end

        private

        def register(type, name, params)
          schema[name] = TYPES[type].new(name, params)
          attr_reader name
        end
      end
    end
  end
end
