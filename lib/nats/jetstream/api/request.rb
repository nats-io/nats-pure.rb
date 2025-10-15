# frozen_string_literal: true

module NATS
  class JetStream
    class API
      class Request
        class << self
          attr_reader :data_schema

          def schema(schema = nil, &block)
            if block
              schema = Class.new(NATS::Utils::Config)
              schema.class_eval(&block)
            end

            @data_schema = schema
          end
        end

        attr_reader :data

        def initialize(data)
          @data = data_schema ? data_schema.new(data) : data
        end

        def to_json
          data.to_json
        end

        private

        def data_schema
          self.class.data_schema
        end
      end
    end
  end
end

require_relative "request/consumer"
require_relative "request/stream"
