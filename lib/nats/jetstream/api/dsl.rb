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

        def request(name, response, subject: true)
          define_request(name, response)

          if subject
            define_request_with_subject(name)
          else
            define_request_without_subject(name)
          end
        end

        private

        def define_reader(name, &block)
          define_method name do
            instance_variable_get("@#{name}") if instance_variable_defined?("@#{name}")
            instance_variable_set("@#{name}", instance_eval(&block))
          end
        end

        def define_request(name, response)
          define_reader "#{name}_request" do
            Request.new(
              name: name, 
              response: response,
              client: client,
              parent: self
            )
          end
        end

        def define_request_with_subject(name)
          define_method name do |subject, data = nil, params = {}|
            send("#{name}_request").request(subject, data, params)
          end
        end

        def define_request_without_subject(name)
          define_method name do |data = nil, params = {}|
            send("#{name}_request").request(nil, data, params)
          end
        end
      end
    end
  end
end
