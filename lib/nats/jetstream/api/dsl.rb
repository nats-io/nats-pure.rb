# frozen_string_literal: true

module NATS
  class JetStream
    class API
      module DSL
        def requests
          @requests ||= {}
        end

        def groups
          @groups ||= {}
        end

        def request(name, response, params = {})
          requests[name] = Request.new(
            group: self,
            name: name,
            response: response
          )

          if params[:subject] == false
            define_request_without_subject(name)
          else
            define_request_with_subject(name)
          end
        end

        def group(name, &block)
          group = Class.new(Group)
          group.class_eval(&block)

          groups[name] = group.new(
            parent: self,
            name: name,
            &block
          )

          groups[name].class

          define_method name do
            groups[name]
          end
        end

        private

        def define_request_with_subject(name)
          define_method name do |subject, data, params = {}|
            request[name].request(
              client: client,
              subject: subject,
              data: data,
              params: params
            )
          end
        end

        def define_request_without_subject(name)
          define_method name do |data = nil, params = {}|
            request[name].request(
              client: client,
              subject: nil,
              data: data,
              params: params
            )
          end
        end
      end
    end
  end
end
