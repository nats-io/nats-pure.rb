# frozen_string_literal: true

module NATS
  module Utils
    class List
      include Enumerable

      attr_reader :parent, :items

      def initialize(parent)
        @parent = parent
        @items = Set.new
      end

      def each(&block)
        @items.each do |item|
          yield item
        end

        self
      end

      def insert(item)
        @items << item
      end
    end
  end
end
