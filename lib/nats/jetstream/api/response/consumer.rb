# frozen_string_literal: true

module NATS
  class JetStream
    class API
      class ConsumerCreateResponse < Response
        schema Consumer::Info
      end

      class ConsumerInfoResponse < Response
        schema Consumer::Info
      end

      class ConsumerDeleteResponse < Response
        schema do
          bool :succes
        end
      end

      class ConsumerListResponse < ListResponse
        schema do
          integer :total
          integer :offset
          integer :limit

          array :consumers, of: Consumer::Info
        end
      end

      class ConsumerNamesResponse < ListResponse
        schema do
          integer :total
          integer :offset
          integer :limit

          array :consumers, of: :string
        end
      end

      class ConsumerLeaderStepdownResponse < Response
        schema do
          bool :succes
        end
      end
    end
  end
end
