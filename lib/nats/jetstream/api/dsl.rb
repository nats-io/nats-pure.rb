# frozen_string_literal: true

module NATS
  class JetStream
    class API
      module DSL
        def group(name, &block)
          klass = Class.new(Group)
          klass.class_eval(&block)

          define_reader name do
            klass.new(
              name: name,
              client: client,
              parent: self
            )
          end
        end

        def endpoint(name, request: Request, response:, subject: true)
          define_endpoint(name, request, response)

          if subject
            define_endpoint_with_subject(name)
          else
            define_endpoint_without_subject(name)
          end
        end

        private

        def define_reader(name, &block)
          define_method name do
            instance_variable_get("@#{name}") if instance_variable_defined?("@#{name}")
            instance_variable_set("@#{name}", instance_eval(&block))
          end
        end

        def define_endpoint(name, request, response)
          define_reader "#{name}_endpoint" do
            Endpoint.new(
              name: name, 
              request: request,
              response: response,
              client: client,
              parent: self
            )
          end
        end

        def define_endpoint_with_subject(name)
          define_method name do |subject, data = {}, params = {}|
            send("#{name}_endpoint").call(subject, data, params)
          end
        end

        def define_endpoint_without_subject(name)
          define_method name do |data = {}, params = {}|
            send("#{name}_endpoint").call(nil, data, params)
          end
        end
      end
    end
  end
end
