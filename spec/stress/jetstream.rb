# frozen_string_literal: true

require_relative "stress"

require_relative "jetstream/test"
require_relative "jetstream/stream"
require_relative "jetstream/params"
require_relative "jetstream/context"

require_relative "jetstream/publisher"
require_relative "jetstream/verbose"

module NATS
  class Stress
    class JetStream < Stress
      test :fetch do
        run FetchTest
        context FetchContext
      end

      test :consume do
        run ConsumeTest
        context ConsumeContext
      end

      test :long do
        run LongTest
        context LongContext
      end

      def initialize(params = {})
        super
        Verbose.on
      end
    end
  end
end
