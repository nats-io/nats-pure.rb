# frozen_string_literal: true

module NATS
  class JetStream
    class API
      class StreamCreateResponse < Response
        schema Stream::Info
      end

      class StreamUpdateResponse < Response
        schema Stream::Info
      end

      class StreamInfoResponse < Response
        schema Stream::Info
      end

      class StreamDeleteResponse < SuccessResponse; end

      class StreamPurgeResponse < SuccessResponse
        schema do
          bool :success
          integer :purged
        end
      end

      class StreamListResponse < ListResponse
        schema do
          integer :total
          integer :offset
          integer :limit

          array :streams, of: Stream::Info
        end
      end

      class StreamNamesResponse < ListResponse
        schema do
          integer :total
          integer :offset
          integer :limit

          array :streams, of: :string
        end
      end

      class StreamMsgGetResponse < Response
        schema do
          object :message do
            # The subject the message was originally received on
            string :subject

            # The sequence number of the message in the Stream
            integer :seq, min: 0

            # The base64 encoded payload of the message body
            string :data

            # The time the message was received
            string :time

            # Base64 encoded headers for the message
            string :hdrs
          end
        end
      end

      class StreamMsgDeleteResponse < SuccessResponse; end

      class StreamSnapshotResponse < Response
        schema do
          object :config, of: Stream::Config
          object :state, of: Stream::State
        end
      end

      class StreamRestoreResponse < Response
        schema do
          string :deliver_subject
        end
      end

      class StreamRemovePeerResponse < SuccessResponse; end
      class StreamLeaderStepdownResponse < SuccessResponse; end
    end
  end
end
