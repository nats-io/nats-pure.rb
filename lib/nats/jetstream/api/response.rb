# frozen_string_literal: true

module NATS
  class JetStream
    class API
      class Response
        class << self
          attr_reader :data_schema

          def inherited(subclass)
            subclass.schema(data_schema)
          end

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
              raise ErrorResponse.new(data[:error]).to_error
            end

            new(data)
          end
        end

        attr_reader :data

        def initialize(data)
          @data = self.class.data_schema.new(data)
        end
      end

      class ListResponse < Response
        def last?
          data.offset + data.limit >= data.total
        end

        def next_page
          data.offset + data.limit
        end
      end

      class SuccessResponse < Response
        schema do
          bool :success
        end

        def success?
          data.success
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

        def to_error
          error = case data.code
          when 503
            ::NATS::JetStream::ServiceUnavailableError
          when 500
            ::NATS::JetStream::ServerError
          when 404
            error_404(data)
          when 400
            ::NATS::JetStream::BadRequestError
          else
            ::NATS::JetStream::APIError
          end

          error.new(data)
        end

        private

        def error_404(data)
          case data.err_code
          when 10059
            ::NATS::JetStream::StreamNotFoundError
          when 10014
            ::NATS::JetStream::ConsumerNotFoundError
          else
            ::NATS::JetStream::NotFoundError
          end
        end
      end
    end
  end
end

require_relative "response/account"
require_relative "response/consumer"
require_relative "response/stream"
