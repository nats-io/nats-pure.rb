# frozen_string_literal: true

module NATS
  class JetStream
    class Api
      class Group
        extend DSL

        attr_reader :name, :client, :subject

        def initialize(parent:, name:)
          @name = name
          @client = parent.client
          @subject = "#{parent.subject}.#{name.upcase}"
        end
      end
    end
  end
end
