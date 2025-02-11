# frozen_string_literal: true

module NATS
  class Utils
    class List
      include Enumerable

      attr_reader :parent

      def initialize(parent)
        @parent = parent
        @items = Set.new
      end

      def each
        @items.each do |item|
          yield item
        end
      end

      def insert(item)
        @items << item
      end
    end
  end
end
