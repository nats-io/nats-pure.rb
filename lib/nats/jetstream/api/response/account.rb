# frozen_string_literal: true

module NATS
  class JetStream
    class API
      class AccountInfoResponse < Response
        schema do
          # Memory Storage being used for Stream Message storage
          integer :memory

          # File Storage being used for Stream Message storage
          integer :storage

          # Number of active Streams
          integer :streams

          # Number of active Consumers
          integer :consumers

          # The JetStream domain this account is in
          string :domain

          object :limits, of: Consumer::Limits

          object :tiers do
            # Memory Storage being used for Stream Message storage
            integer :memory

            # File Storage being used for Stream Message storage
            integer :storage

            # Number of active Streams
            integer :streams

            # Number of active Consumers
            integer :consumers

            object :limits, of: Consumer::Limits
          end

          object :api do
            # Total number of API requests received for this account
            integer :total

            # API requests that resulted in an error response
            integer :errors
          end
        end
      end
    end
  end
end
