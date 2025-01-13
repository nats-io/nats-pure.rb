# frozen_string_literal: true

module NATS
  class Configuration
    class Option
      attr_reader :name, :params

      def initialize(name, params)
        @name = name
        @params = params
      end

      def value(options)
        [hash(options), env, default].compact.first
      end

      private

      def hash(options)
        typecast(options[name])
      end

      def env
        typecast(ENV[params[:env]]) if params[:env]
      end

      def default
        params[:default]
      end

      def typecast(value)
        return if value.nil?

        case params[:type]
        when :bool
          %w[1 true t].include?(value.to_s.downcase)
        when :int
          value.to_i if value.respond_to?(:to_i)
        end
      end
    end

    class << self
      def options
        @options ||= {}
      end

      def option(name, params)
        options[name] = Option.new(name, params)
        attr_reader name
      end
    end

    option :verbose, type: :bool, env: "NATS_VERBOSE", default: false
    option :pedantic, type: :bool, env: "NATS_PEDANTIC", default: false
    option :old_style_request, type: :bool, default: false

    option :ignore_discovered_urls, type: :bool, env: "NATS_IGNORE_DISCOERED_URLS", default: false

    option :reconnect, type: :bool, env: "NATS_RECONNECT", default: true
    option :reconnect_time_wait, type: :int, env: "NATS_RECONNECT_TIME_WAIT", default: 2
    option :max_reconnect_attempts, type: :int, env: "NATS_MAX_RECONNECT_ATTEMPTS", default: 10

    option :ping_interval, type: :int, env: "NATS_PING_INTERVAL", default: 120
    option :max_outstanding_pings, type: :int, env: "NATS_MAX_OUTSTANDING_PINGS", default: 2

    option :connect_timeout, type: :int, default: 2
    option :drain_timeout, type: :int, default: 30
    option :close_timeout, type: :int, default: 30

    def initialize(options)
      self.class.options.each do |name, option|
        instance_variable_set("@#{name}", option.value(options))
      end
    end
  end
end
