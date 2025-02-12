# frozen_string_literal: true

module NATS
  class JetStream
    class Stream
      class Config < NATS::Utils::Config
        option :name, type: NameType
        option :storage, type: NominalType["file", "memory"], default: "file"
        option :subjects, type: ArrayType[StringType], editable: true
        option :num_replicas, type: ReplicasType, editable: true

        option :max_age, type: IntegerType, editable: true
        option :max_bytes, type: IntegerType, editable: true
        option :max_msgs, type: IntegerType, editable: true
        option :max_msg_size, type: IntegerType, editable: true
        option :max_consumers, type: IntegerType

        option :no_ack, type: BoolType, default: false
        option :retention, type: NominalType["limits", "work_queue", "interest"], default: "limits"

        option :discard, type: NominalType["old", "new"], default: "old", editable: true
        option :duplicate_window, type: IntegerType, editable: true

        option :placement, editable: true do
          option :cluster, type: StringType
          option :tags, type: StringType
        end

        option :mirror, type: StringType
        option :sources, type: ArrayType[StringType], editable: true

        option :max_msgs_per_subject, type: IntegerType, editable: true
        option :description, type: StringType, editable: true
        option :sealed, type: BoolType

        option :deny_delete, type: BoolType
        option :deny_purge, type: BoolType

        option :allow_rollup, type: BoolType, editable: true

        option :re_publish, editable: true do
          option :source, type: StringType
          option :destination, type: StringType
          option :headers_only, type: StringType
        end

        option :allow_direct, type: BoolType, editable: true
        option :mirror_direct, type: BoolType, editable: true
        option :discard_new_per_subject, type: BoolType, editable: true

        option :metadata, type: HashType, editable: true
        option :compression, type: StringType, editable: true

        option :first_seq, type: StringType

        option :subject_transform, editable: true do
          option :source, type: StringType
          option :destination, type: StringType
        end

        option :consumer_limits, type: IntegerType, editable: true

        class NameType < StringType
          def validate(value)
            NATS::Utils::Validator.validate(name: value)
          end
        end

        class ReplicasType < IntegerType
          def validate(value)
            raise "" if value > 5
          end
        end
      end
    end
  end
end
