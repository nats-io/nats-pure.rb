# frozen_string_literal: true

module NATS
  class JetStream
    class API
      class StreamCreateRequest < Request
        schema Stream::Config
      end

      class StreamUpdateRequest < Request
        schema Stream::Config
      end

      class StreamInfoRequest < Request
        schema do
          # When true will result in a full list of deleted message 
          # IDs being returned in the info respons
          bool :deleted_details

          # When set will return a list of subjects and how many messages 
          # they hold for all matching subjects. Filter is a standard NATS 
          # subject wildcard pattern
          string :subjects_filter

          # Paging offset when retrieving pages of subject details
          integer :offset, min: 0
        end
      end

      class StreamPurgeRequest < Request
        schema do
          # Restrict purging to messages that match this subject
          string :filter

          # Purge all messages up to but not including the message with
          # this sequence. Can be combined with subject filter but
          # not the keep option
          integer :seq, min: 0

          # Ensures this many messages are present after the purge.
          # Can be combined with the subject filter but not the sequence
          integer :keep, min: 0
        end
      end

      class StreamListRequest < Request
        schema do
          # Limit the list to streams matching this subject filter
          string :subject

          # Paging offset
          integer :offset, min: 0
        end
      end

      class StreamNamesRequest < Request
        schema do
          # Limit the list to streams matching this subject filter
          string :subject

          # Paging offset
          integer :offset, min: 0
        end
      end

      class StreamMsgGetRequest < Request
        schema do
          # Stream sequence number of the message to retrieve,
          # cannot be combined with last_by_subj
          integer :seq

          # Retrieves the last message for a given subject,
          # cannot be combined with seq
          string :last_by_subj

          # Combined with sequence gets the next message 
          # for a subject with the given sequence or higher
          string :next_by_subj
        end
      end

      class StreamSnapshotRequest < Request
        schema do
          # The NATS subject where the snapshot will be delivered
          string :deliver_subject

          # When true consumer states and configurations will not 
          # be present in the snapshot
          bool :no_consumers

          # The size of data chunks to send to deliver_subject
          integer :chunk_size, min: 1024

          # Check all message's checksums prior to snapshot
          bool :jsck, default: false
        end
      end

      class StreamRestoreRequest < Request
        schema do
          object :config, of: Stream::Config
          object :state, of: Stream::State
        end
      end

      class StreamRemovePeerRequest < Request
        schema do
          # Server name of the peer to remove
          string :peer
        end
      end
    end
  end
end
