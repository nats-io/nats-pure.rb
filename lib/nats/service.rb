# frozen_string_literal: true

require "monitor"

require_relative "service/extension"
require_relative "service/group"
require_relative "service/endpoint"
require_relative "service/errors"

require_relative "service/validator"
require_relative "service/callbacks"
require_relative "service/monitoring"
require_relative "service/status"
require_relative "service/stats"

module NATS
  class Service
    include MonitorMixin
    include Extension

    DEFAULT_QUEUE = "q"

    attr_reader :client, :name, :id, :version, :description, :metadata, :queue
    attr_reader :monitoring, :status, :callbacks, :groups, :endpoints

    alias_method :subject, :name

    def initialize(client, options)
      super()
      validate(options)

      setup_options(options)
      setup_internals(client)
    end

    def on_stats(&block)
      callbacks.register(:stats, &block)
    end

    def on_stop(&block)
      callbacks.register(:stop, &block)
    end

    def stopped?
      !!@stopped
    end

    def stop(error = nil)
      return if stopped?

      synchronize do
        monitoring&.stop
        endpoints&.each(&:stop)

        callbacks&.call(:stop, error)
      end
    ensure
      synchronize { @stopped = true }
    end

    def reset
      endpoints.each(&:reset)
    end

    def info
      status.info
    end

    def stats
      status.stats
    end

    def service
      self
    end

    private

    def validate(options)
      Validator.validate(options.slice(:name, :version, :queue))
    end

    def setup_options(options)
      @name = options[:name]
      @version = options[:version]
      @description = options[:description]
      @metadata = options[:metadata].freeze
      @queue = options[:queue] || DEFAULT_QUEUE
    end

    def setup_internals(client)
      @client = client
      @id = NATS::NUID.next

      @monitoring = Monitoring.new(self)
      @status = Status.new(self)
      @callbacks = Callbacks.new(self)

      @groups = []
      @endpoints = []
    end
  end
end
