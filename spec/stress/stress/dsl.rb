# frozen_string_literal: true

module NATS
  class Stress
    module DSL
      module Stress
        def tests
          @tests ||= TestDefinitions.new
        end

        def test(name, &block)
          definition = TestDefinition.new(name)
          definition.instance_eval(&block)

          tests[name] = definition
        end
      end

      module Test
        def run(klass = nil, &block)
          @run = RunDefinition.new(klass)
        end

        # def context(name, klass = nil, &block)
        # @context.one(name, klass, &block)
        # end

        def context(klass = nil, &block)
          @context = ContextDefinition.new(klass, &block)
        end
      end
    end
  end
end
