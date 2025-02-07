# frozen_string_literal: true

module NATS
  module Utils
    module Nsec
      def to_nsec
        (self * 1_000_000_000).to_i
      end

      def from_nsec
        self / 1_000_000_000.0
      end
    end
  end
end

Numeric.include NATS::Utils::Nsec
