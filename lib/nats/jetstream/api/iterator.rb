# frozen_string_literal: true

module NATS
  class JetStream
    class API
      class Iterator
        include Enumerable

        attr_reader :api, :js, :default_params, :options

        def initialize(api:, params:, options:, &block)
          @api = api
          @js = api.js

          @default_params = params
          @options = options

          instance_eval(&block)
        end

        def request(&block)
          @request = block
        end

        def iterate(&block)
          @iterate = block
        end

        def each(&block)
          enumerator.each(&block)
        end

        private

        def enumerator
          @enumerator ||= Enumerator.new do |yielder|
            params = default_params

            begin
              response = @request.call(params)
              @iterate.call(response, yielder)

              params.merge!(offset: response.next_page)
            end until response.last?
          end
        end
      end
    end
  end
end
