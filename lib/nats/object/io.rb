# frozen_string_literal: true

module NATS
  class Object
    class IO
      attr_reader :info, :options

      def initialize(store, info, options = {})
        @info = info
        @options = options
        @chunks = NATS::Object::Get::Chunks.new(store)
      end

      def read(*args)
        file.read(*args)
      end

      def eof?
        file.eof?
      end

      def close
        file.close
      end

      def closed?
        file.closed?
      end

      def file
        unless defined?(@file)
          @data = @chunks.get(info, options)
          @file = File.new(@data.io.path)
        end

        @file
      end
    end
  end
end
