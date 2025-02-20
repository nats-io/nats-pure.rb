# frozen_string_literal: true

module NATS
  class JetStream
    class Stream 
      class State < NATS::Utils::Config
        # Number of messages stored in the Stream
        integer :messages, min: 0

        # Combined size of all messages in the Stream
        integer :bytes, min: 0

        # Sequence number of the first message in the Stream
        integer :first_seq, min: 0

        # The timestamp of the first message in the Strea
        string :first_ts

        # Sequence number of the last message in the Stream
        integer :last_seq, min: 0

        # The timestamp of the last message in the Strea
        string :last_ts

        # IDs of messages that were deleted using the Message Delete API 
        # or Interest based streams removing messages out of order
        array :deleted, of: :integer

        # Subjects and their message counts when a subjects_filter was set
        hash :subjects

        # The number of unique subjects held in the stream
        integer :num_subjects, min: 0

        # The number of deleted messages
        integer :num_deleted, min: 0

        # Records messages that were damaged and unrecoverable
        object :last do
          # The messages that were lost
          array :msgs, of: :integer

          # The number of bytes that were lost
          integer :bytes
        end

        # Number of Consumers attached to the Stream
        integer :consumer_count, min: 0
      end
    end
  end
end
