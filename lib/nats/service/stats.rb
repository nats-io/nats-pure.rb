# frozen_string_literal: true

require "monitor"

module NATS
  class Service
    class Stats
      include MonitorMixin

      attr_reader :num_requests, :num_errors, :last_error, :processing_time, :average_processing_time

      def initialize
        super
        reset
      end

      def reset
        synchronize do
          @num_requests = 0
          @processing_time = 0
          @average_processing_time = 0

          @num_errors = 0
          @last_error = ""
        end
      end

      def record(started_at)
        synchronize do
          @num_requests += 1
          @processing_time += to_nsec(Time.now - started_at)
          @average_processing_time = @processing_time / @num_requests
        end
      end

      def error(error)
        synchronize do
          @num_errors += 1
          @last_error = error.message
        end
      end

      private

      def to_nsec(seconds)
        (seconds * 10**9).to_i
      end
    end
  end
end
