# frozen_string_literal: true

module NATS
  class JetStream
    class Message < NATS::Utils::Config
      class Metadata < NATS::Utils::Config
        # $JS.ACK.<stream>.<consumer>.<delivered>.<sseq>.<cseq>.<tm>.<pending>
        V1_TOKENS = [
          :js,
          :ack,
          :stream,
          :consumer,
          :num_delivered,
          :stream_seq,
          :consumer_seq,
          :timestamp,
          :num_pending
        ].freeze

        # $JS.ACK.<domain>.<account hash>.<stream>.<consumer>.<delivered>.<sseq>.<cseq>.<tm>.<pending>.<a token with a random value>
        V2_TOKENS = [
          :js,
          :ack,
          :domain,
          :account_hash,
          :stream,
          :consumer,
          :num_delivered,
          :stream_seq,
          :consumer_seq,
          :timestamp,
          :num_pending
        ].freeze

        string :stream
        string :consumer
        string :domain

        object :sequence do
          integer :stream
          integer :consumer
        end

        integer :num_delivered
        integer :num_pending

        string :timestamp

        alias_method :seq, :sequence

        def initialize(reply)
          tokens = tokens(reply)

          tokens[:sequence] = {
            stream: tokens[:stream_seq],
            consumer: tokens[:consumer_seq]
          }

          super(tokens)
        end

        private

        def tokens(reply)
          raise NotJsMessageError if reply.nil?

          values = reply.split(".")
          version = version(values)

          version.zip(values).to_h
        end

        def version(values)
          return V1_TOKENS if values.size == 9
          return V2_TOKENS if values.size >= 11

          raise NotJsMessageError
        end
      end
    end
  end
end
