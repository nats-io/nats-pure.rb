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
          bool :success
        end
      end

      class StreamPurgeResponse < Response
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
        schema Message::Info
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
