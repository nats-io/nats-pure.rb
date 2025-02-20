# frozen_string_literal: true

module NATS
  class JetStream
    class Message
      class Info < NATS::Utils::Config
        # The subject the message was originally received on
        string :subject

        # The sequence number of the message in the Stream
        integer :seq

        # The base64 encoded payload of the message body
        string :data

        # The time the message was receive
        string :time

        # Base64 encoded headers for the messag
        string :hdrs
      end
    end
  end
end
