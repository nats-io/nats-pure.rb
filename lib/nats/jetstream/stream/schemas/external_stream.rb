# frozen_string_literal: true

module NATS
  class JetStream
    class Stream
      # Configuration referencing a stream source in another 
      # account or JetStream domain
      class ExternalStream < NATS::Utils::Config
        # The subject prefix that imports the other account/domain 
        # $JS.API.CONSUMER.> subject
        string :api

        # The delivery subject to use for the push consume
        string :deliver
      end
    end
  end
end
