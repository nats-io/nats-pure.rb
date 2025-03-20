# frozen_string_literal: true

module NATS
  class JetStream
    class Publisher
      class Ack < NATS::Utils::Config
        # Stream is the stream name the message was published to
        string :stream

        # Sequence is the stream sequence number of the message
        integer :seq

        # Duplicate indicates whether the message was a duplicate
        bool :duplicate

        # Domain is the domain the message was published to
        string :domain

        class << self
          def build(message)
            data = JSON.parse(message.data, symbolize_names: true)

            if data[:error]
              raise Api::ErrorResponse.new(data[:error]).to_error
            end

            new(data)
          end
        end
      end
    end
  end
end
