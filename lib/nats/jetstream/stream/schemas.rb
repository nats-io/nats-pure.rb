# frozen_string_literal: true

module NATS
  class JetStream
    class Stream
      # Subject transform to apply to matching messages going into the stream
      class SubjectTransform < NATS::Utils::Config
        # The subject transform sourc
        string :src, required: true

        # The subject transform destinatio
        string :dst, required: true
      end

      # Configuration referencing a stream source in another 
      # account or JetStream domain
      class ExternalStream < NATS::Utils::Config
        # The subject prefix that imports the other account/domain 
        # $JS.API.CONSUMER.> subject
        string :api

        # The delivery subject to use for the push consume
        string :deliver
      end

      #
      class StreamSource < NATS::Utils::Config
        string :name, required: true
        integer :opt_start_seq
        integer :opt_start_time
        string :filter_subject

        object :external, of: ExternalStream
        array :subject_transforms, of: SubjectTransform

        string :domain
      end

      #
      class StreamSourceInfo < NATS::Utils::Config
        # The name of the Stream being replicate
        string :name

        # The subject filter to apply to the message
        string :filter_subject

        # The subject filtering sources and associated destination transforms
        # Subject transform to apply to matching messages going into the stream
        array :subject_transforms, of: SubjectTransform

        # How many messages behind the mirror operation is
        integer :lag, min: 0

        # When last the mirror had activity, in nanoseconds. Value will be -1 when there has been no activity.
        integer :active, min: -1

        # Configuration referencing a stream source in another account or JetStream domain
        object :external, of: ExternalStream
      end
    end
  end
end
