# frozen_string_literal: true

module NATS
  module Utils
    class Config
      class Option
        attr_reader :name, :params, :type

        def initialize(name, params)
          @name = name
          @params = params
          @type = params[:type].instance
        end

        def value(options)
          value = fetch(options)
          value = type.value(value)

          value || params[:default]
        end

        def editable?
          params[:editable]
        end

        private

        def fetch(options)
          options[name] || ENV[params[:env]]
        end
      end
    end
  end
end
