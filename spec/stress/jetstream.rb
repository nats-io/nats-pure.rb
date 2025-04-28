# frozen_string_literal: true

require_relative "stress"

require_relative "jetstream/test"
require_relative "jetstream/stream"
require_relative "jetstream/params"
require_relative "jetstream/context"

require_relative "jetstream/publisher"
require_relative "jetstream/verbose"

# To run all JetStream stress tests:
#   require "./spec/stress/jetstream"
#   NATS::Stress::JetStream.new.run
#
# To run specific tests:
#   NATS::Stress::JetStream.new(test: [:fetch, :consume]).run
#
# To run specific contexts:
#   NATS::Stress::JetStream.new(context: [:small_stream, :large_stream]).run
#
# To run on a different number of processes (10 by default):
#   NATS::Stress::JetStream.new(processes: 5).run
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
