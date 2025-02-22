# frozen_string_literal: true

module NATS
  class JetStream
    class API
      class Iterator
        include Enumerable

        def initialize(params, &block)
          @default_params = params
          @block = block
        end

        def each(&block)
          enumerator.each(&block)
        end

        private

        def enumerator
          @enumerator ||= Enumerator.new do |yielder|
            params = @default_params

            begin
              response = @block.call(params, yielder)
              params.merge!(offset: response.next_page)
            end until response.last?
          end
        end
      end
    end
  end
end
