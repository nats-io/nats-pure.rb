# frozen_string_literal: true

module NATS
  class JetStream
    class API
      module DSL
        def group(name, &block)
          klass = Class.new(Group)
          klass.class_eval(&block)

          define_reader name do
            klass.new(parent: self, name: name)
          end
        end

        def endpoint(name, response:, request: Request, subject: true)
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
            if instance_variable_defined?("@#{name}")
              return instance_variable_get("@#{name}")
            end

            instance_variable_set("@#{name}", instance_eval(&block))
          end
        end

        def define_endpoint(name, request, response)
          define_reader "#{name}_endpoint" do
            Endpoint.new(
              parent: self,
              name: name,
              request: request,
              response: response
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
