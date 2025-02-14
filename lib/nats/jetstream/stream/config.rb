# frozen_string_literal: true

module NATS
  class JetStream
    class Stream
      class Config < NATS::Utils::Config
        #name: Optional[str] = None
        string :name, as: :name, required: true
        #description: Optional[str] = None
        string :description

        #storage: Optional[StorageType] = None
        string :storage, in: %w[file memory], default: "file"
        #subjects: Optional[List[str]] = None
        array :subjects, of: :string
        #array :subjects, of: { type: :string, as: :subject }
        #num_replicas: Optional[int] = None
        integer :num_replicas, in: (0..5)

        #max_age: Optional[float] = None  # in seconds
        integer :max_age
        #max_bytes: Optional[int] = None
        integer :max_bytes
        #max_msgs: Optional[int] = None
        integer :max_msgs
        #max_msg_size: Optional[int] = -1
        integer :max_msg_size, default: -1
        #max_consumers: Optional[int] = None
        integer :max_consumers
        #max_msgs_per_subject: int = -1
        integer :max_msgs_per_subject, default: -1

        #no_ack: bool = False
        bool :no_ack, default: false
        #retention: Optional[RetentionPolicy] = None
        string :retention, in: %w[limits work_queue interest], default: "limits"

        #discard: Optional[DiscardPolicy] = DiscardPolicy.OLD
        string :discard, in: %w[old new], default: "old"
        #discard_new_per_subject: bool = False
        bool :discard_new_per_subject, default: false

        #duplicate_window: float = 0
        integer :duplicate_window, default: 0

        #placement: Optional[Placement] = None
        object :placement do
          string :cluster
          array :tags, of: :string
        end

        #mirror: Optional[StreamSource] = None
        object :mirror, of: :stream_source
        #sources: Optional[List[StreamSource]] = None
        array :sources, of: :stream_source

        #sealed: bool = False
        bool :sealed, default: false
        #deny_delete: bool = False
        bool :deny_delete, default: false
        #deny_purge: bool = False
        bool :deny_purge, default: false
        #allow_rollup_hdrs: bool = False
        bool :allow_rollup, default: false

        #republish: Optional[RePublish] = None
        object :republish do
          string :source
          string :destination
          bool :headers_only
        end

        #subject_transform: Optional[SubjectTransform] = None
        object :subject_transform, of: :subject_transform

        #allow_direct: Optional[bool] = None
        bool :allow_direct
        #mirror_direct: Optional[bool] = None
        bool :mirror_direct

        #compression: Optional[StoreCompression] = None
        string :compression, in: %w[none s2]

        #metadata: Optional[Dict[str, str]] = None
        hash :metadata

        string :first_seq
        integer :consumer_limits

        # Custom Types

        type :stream_source do
          string :name, required: true
          #opt_start_seq: Optional[int] = None
          integer :opt_start_seq
          #opt_start_time: Optional[str] = None
          string  :opt_start_time
          #filter_subject: Optional[str] = None
          string :filter_subject
          #external: Optional[ExternalStream] = None
          object :external do
            string :api, required: true
            string :deliver
          end

          #subject_transforms: Optional[List[SubjectTransform]] = None
          array :subject_transforms, of: :subject_transform
        end

        type :subject_transform do
          string :src, required: true
          string :dst, required: true
        end
      end
    end
  end
end
