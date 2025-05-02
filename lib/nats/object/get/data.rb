# frozen_string_literal: true

module NATS
  class Object
    class Get
      class Data
        include MonitorMixin

        attr_reader :io, :options, :error

        def initialize(info, options)
          super()

          @info = info
          @options = options
          @io = options.io

          @sha256 = Digest::SHA256.new
          @done_cond = new_cond
          @error = nil
        end

        def <<(chunk)
          synchronize do
            @io << chunk
            @sha256 << chunk
          end
        end
        alias_method :write, :<<

        def close(error = nil)
          synchronize do
            @io.close
            @error = error
            @done_cond.signal
          end
        end

        def wait(timeout = nil)
          synchronize do
            @done_cond.wait(timeout)
          end
        end

        def digest
          synchronize { @sha256.digest }
        end

        def valid?
          digest == @info.raw_digest
        end

        def data
          options.as_string? ? io.string : io
        end
      end
    end
  end
end
