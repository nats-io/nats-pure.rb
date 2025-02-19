# frozen_string_literal: true

module NATS
  class JetStream
    class API
      class Group
        extend DSL

        attr_reader :client, :subject

        def initialize(name:, parent:, client:)
          @name = name
          @client = client
          @subject = "#{parent.subject}.#{name.upcase}"
        end
      end
    end
  end
end
