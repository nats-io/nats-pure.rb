# frozen_string_literal: true

module NATS
  class JetStream
    class API
      class Group
        extend DSL

        attr_reader :subject

        def initialize(name:, parent:)
          @name = name
          @parent = parent
          @subject = "#{parent.subject}.#{name}"
        end
      end
    end
  end
end
