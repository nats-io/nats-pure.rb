# frozen_string_literal: true

module NATS
  class Stress
    class Logger
      def initialize
        # FileUtils.mkdir_p(filepath)
        FileUtils.mkdir_p("tmp/stress/fetch")
        FileUtils.mkdir_p("tmp/stress/consume")
        FileUtils.mkdir_p("tmp/stress/long-consume")

        @files = {}
      end

      def write(results)
        results.each do |filename, log|
          file(filename).write(log)
        end

        @files.values.each(&:close)
      end

      private

      def file(filename)
        filename = "#{filepath}/#{filename}.log"

        @files[filename] ||= File.open(filename, "w")
      end

      def filepath
        # @filepath ||= "tmp/stress/#{Time.now.to_i}"
        @filepath ||= "tmp/stress"
      end
    end
  end
end
