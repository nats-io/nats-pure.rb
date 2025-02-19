# frozen_string_literal: true

module NATS
  class JetStream
    class Stream
      class StreamSource < NATS::Utils::Config
        string :name, required: true
        integer :opt_start_seq
        integer :opt_start_time
        string :filter_subject

        object :external, of: ExternalStream
        array :subject_transforms, of: SubjectTransform

        string :domain
      end

      class StreamSourceInfo < NATS::Utils::Config
        # The name of the Stream being replicate
        string :name

        # The subject filter to apply to the message
        string :filter_subject

        # The subject filtering sources and associated destination transforms
        # Subject transform to apply to matching messages going into the stream
        array :subject_transforms, of: SubjectTransform

        # How many messages behind the mirror operation is
        integer :lag, min: 0, max: 18446744073709551615

        # When last the mirror had activity, in nanoseconds. Value will be -1 when there has been no activity.
        integer :active, min: -1, max: 9223372036854775807

        # Configuration referencing a stream source in another account or JetStream domain
        object :external, of: ExternalStream

        object :error, as: ErrorResponse
      end
    end
  end
end
