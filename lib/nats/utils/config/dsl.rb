# frozen_string_literal: true

module NATS
  module Utils
    class Config
      module DSL
        attr_accessor :configs

        OPTIONS = {
          string: NATS::Utils::Config::StringOption,
          integer: NATS::Utils::Config::IntegerOption,
          bool: NATS::Utils::Config::BoolOption,
          hash: NATS::Utils::Config::HashOption,
          array: NATS::Utils::Config::ArrayOption,
          object: NATS::Utils::Config::ObjectOption
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
          config = of_config(name, params)

          if config
            params[:item] = ObjectOption.new(name, config: config)
          else
            params[:item] = OPTIONS[params[:of]].new(name, params)
          end

          register(:array, name, params)
        end

        def object(name, params = {}, &block)
          config(name, &block) if block
          params[:config] = of_config(name, params)

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
          schema[name] = OPTIONS[type].new(name, params)
          attr_reader name
        end

        def of_config(name, params)
          if params[:of].is_a?(Class)
            params[:of]
          else
            configs[params[:of] || name]
          end
        end
      end
    end
  end
end
