# frozen_string_literal: true

require "logger"

module NATS
  class Stress
    class Test
      attr_reader :logger, :context

      def initialize(context)
        @context = context

        @logdev = StringIO.new
        @logger = ::Logger.new(@logdev)
      end

      def cleanup
        logger.close
      end

      def log
        @logdev.string
      end

      def info
        context
      end
    end
  end
end
