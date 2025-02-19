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
    end
  end
end
