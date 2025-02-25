# frozen_string_literal: true

require_relative "message/list"

module NATS
  class JetStream
    class Message < NATS::Utils::Config
      string :subject
      string :data
      hash :header

      integer :seq
      string :time

      attr_reader :stream

      def initialize(stream, config)
        @stream = stream
        super config
      end

      def delete
        raise "" unless seq
        js.api.stream.msg.delete(seq).success?
      end
    end
  end
end
