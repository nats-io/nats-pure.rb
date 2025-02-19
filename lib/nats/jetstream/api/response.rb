# frozen_string_literal: true

module NATS
  class JetStream
    class API
      class Response
        class << self
          def build(json)
          end

          def schema(schema, &block)
            @schema = schema
          end
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
