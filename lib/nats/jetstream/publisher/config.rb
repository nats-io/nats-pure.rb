# frozen_string_literal: true

module NATS
  class JetStream
    class Publisher
      class Config < NATS::Utils::Config
        # Used to assert the published message is received
        # by some expected stream
        string :stream

        # Client-defined unique identifier for a message
        # that will be used by the server apply de-duplication
        # within the configured Duplicate Window
        string :message_id

        # Used to apply optimistic concurrency control at
        # the stream-level. The value is the last expected
        # Nats-Msg-Id and the server will reject a publish
        # if the current ID does not match
        string :last_message_id

        # Used to apply optimistic concurrency control at
        # the stream-level. The value is the last expected
        # sequence and the server will reject a publish if
        # the current sequence does not match
        string :last_seq

        # Used to apply optimistic concurrency control at
        # the subject-level. The value is the last expected
        # sequence and the server will reject a publish if
        # the current sequence does not match for the
        # message's subject
        string :last_subject_seq

        # Used to apply a purge of all prior messages in
        # the stream or at the subject-level
        string :rollup, in: %w[stream sub]

        # Custom header
        hash :header

        # Timeout for the publish request
        integer :timeout

        HEADERS = {
          message_id: "Nats-Msg-Id",
          stream: "Nats-Expected-Stream",
          last_message_id: "Nats-Expected-Last-Msg-Id",
          last_seq: "Nats-Expected-Last-Sequence",
          last_subject_seq: "Nats-Expected-Last-Subject-Sequence",
          rollup: "Nats-Rollup"
        }.freeze

        def headers
          HEADERS.each_with_object(header || {}) do |(option, header), hash|
            hash[header] = self[option] if self[option]
          end
        end
      end
    end
  end
end
