# frozen_string_literal: true

module NATS
  class Stress
    class TestDefinitions < Hash
      def only(names)
        names ? slice(*names) : self
      end

      def materialize(params)
        only(params[:test]).map do |name, test|
          test.materialize(params)
        end.flatten
      end
    end

    class TestDefinition
      include DSL::Test

      def initialize(name)
        @name = name
      end

      def materialize(params)
        @context.materialize(params).map do |context|
          @run.build(context)
        end
      end
    end

    class RunDefinition
      def initialize(klass, &block)
        @klass = klass
      end

      def build(context)
        @klass.new(context)
      end
    end

    class ContextDefinition
      def initialize(klass, &block)
        @klass = klass
      end

      def materialize(params)
        @klass.new.materialize(params)
      end
    end
  end
end
