# frozen_string_literal: true

module NATS
  module Utils
    class Config
      module DSL
        attr_writer :configs

        OPTIONS = {
          string: NATS::Utils::Config::StringOption,
          integer: NATS::Utils::Config::IntegerOption,
          bool: NATS::Utils::Config::BoolOption,
          date: NATS::Utils::Config::DateOption,
          time: NATS::Utils::Config::TimeOption,
          hash: NATS::Utils::Config::HashOption,
          array: NATS::Utils::Config::ArrayOption,
          object: NATS::Utils::Config::ObjectOption
        }.freeze

        def inherited(subclass)
          subclass.schema.merge!(schema)
        end

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

        def date(name, params = {})
          register(:date, name, params)
        end

        def time(name, params = {})
          register(:time, name, params)
        end

        def hash(name, params = {})
          register(:hash, name, params)
        end

        def array(name, params = {}, &block)
          config(name, &block) if block
          config = of_config(name, params)

          params[:item] = if config
            ObjectOption.new(name, config: config)
          else
            OPTIONS[params[:of]].new(name)
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
