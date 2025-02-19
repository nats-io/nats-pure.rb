# frozen_string_literal: true

module NATS
  class JetStream
    class API
      class Response
        class << self
          attr_reader :data_schema

          def schema(schema = nil, &block)
            if block
              schema = Class.new(NATS::Utils::Config)
              schema.class_eval(&block)
            end

            @data_schema = schema
          end

          def build(message)
            data = JSON.parse(message.data, symbolize_names: true)

            if data[:error]
              ErrorResponse.new(data[:error])
            else
              new(data)
            end
          end
        end

        attr_reader :data

        def initialize(data)
          @data = self.class.data_schema.new(data)
        end
      end

      class ErrorResponse < Response
        schema do
          # HTTP like error code in the 300 to 500 range
          integer :code, min: 300, max: 699

          # A human friendly description of the erro
          string :description

          # The NATS error code unique to each kind of error
          integer :err_code, min: 0, max: 65535
        end
      end
    end
  end
end

require_relative "response/account"
require_relative "response/consumer"
require_relative "response/stream"
