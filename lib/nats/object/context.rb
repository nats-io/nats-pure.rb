# frozen_string_literal: true

module NATS
  class Object
    class Context
      attr_reader :js, :client, :stores

      def initialize(client, options = {})
        @client = client
        @js = options[:js] || client.js(options)
        @stores = Store::List.new(self)
      end
    end
  end
end
