# frozen_string_literal: true

require "monitor"

require_relative "service/group"
require_relative "service/endpoint"
require_relative "service/errors"

require_relative "service/callbacks"
require_relative "service/monitoring"
require_relative "service/status"
require_relative "service/stats"

module NATS
  class Service
    class Config < NATS::Utils::Config
      string :name, as: :name
      string :version, as: :version
      string :description
      string :queue, default: "q"

      hash :metadata
    end

    include MonitorMixin

    attr_reader :client, :config, :id, :monitoring, :status, :callbacks, :groups, :endpoints

    def initialize(client, options)
      super()

      @config = Config.new(options)

      @client = client
      @id = NATS::NUID.next

      @monitoring = Monitoring.new(self)
      @status = Status.new(self)
      @callbacks = Callbacks.new(self)

      @groups = Groups.new(self)
      @endpoints = Endpoints.new(self)
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

    def subject
      nil
    end
  end

  class Services < NATS::Utils::List
    attr_reader :client

    def initialize(client)
      @client = client
      super
    end

    def add(options)
      client.synchronize do
        service = NATS::Service.new(client, options)
        insert(service)

        service
      end
    end
  end
end
