# frozen_string_literal: true

module NATS
  class Compability
    class JetStream
      attr_reader :client, :js

      def initialize
        @client = NATS.connect("js:js@ev.nats.dev")
        @js = client.jetstream
      end

      def fetch(params = {})
        consumer.fetch(params).each do |message|
          puts "Message fetched: #{message.inspect}"
        end
      end

      def next(params = {})
        consumer.next(params)
      end

      def consume(params = {})
        consume = consumer.consume(params) do |message|
          puts "Message consumed: #{message.inspect}"
        end

        consume.wait(30)
        consume.drain
        consume
      end

      private

      def consumer
        sources.consumers.upsert(name: "consumer")
      end

      def benchstream
        @benchstream ||= js.streams.find("benchstream")
      end

      def quuz
        @quuz ||= js.streams.find("quuz")
      end

      def sources
        @sources ||= js.streams.find("sources")
      end
    end
  end
end
