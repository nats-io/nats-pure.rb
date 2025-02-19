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

      class StreamDeleteResponse < Response
        schema do
          bool :succes
        end
      end

      class StreamPurgeResponse < Response
        schema do
          bool :success
          integer :purged
        end
      end

      class StreamListResponse < Response
        schema do
          integer :total
          integer :offset
          integer :limit

          array :streams, of: Stream::Info
        end
      end

      class StreamNamesResponse < Response
        schema do
          integer :total
          integer :offset
          integer :limit

          array :streams, of: :string
        end
      end

      class StreamMsgGetResponse < Response
        schema do
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

      class StreamMsgDeleteResponse < Response
        schema do
          bool :success
        end
      end

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

      class StreamRemovePeerResponse < Response
        schema do
          bool :success
        end
      end

      class StreamLeaderStepdownResponse < Response
        schema do
          bool :success
        end
      end
    end
  end
end
