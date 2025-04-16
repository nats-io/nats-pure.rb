# frozen_string_literal: true

require "parallel"

require_relative "stress/dsl"
require_relative "stress/definition"
require_relative "stress/test"
require_relative "stress/logger"

module NATS
  class Stress
    extend DSL::Stress

    attr_reader :params, :logger

    def initialize(params = {})
      @params = params
      @logger = Logger.new
    end

    def run
      puts "Stress starts to accumulate..."

      results = Parallel.map(tests, in_processes: processes) do |test|
        puts "=> Running #{test.info}"

        test.run
        test.cleanup

        puts "=> Completed #{test.info}"

        [test.logfile, test.log]
      rescue => error
        puts error.message
        puts error.backtrace
        next
      end

      logger.write(results)

      puts "Stress overwhelmed you...(x_x)"
    end

    def setup
      tests.each(&:setup)
    end

    def cleanup
      tests.each(&:cleanup)
    end

    def tests
      @tests ||= self.class.tests.materialize(params)
    end

    private

    def processes
      params[:processes] || 10
    end
  end
end
