# frozen_string_literal: true

module NATS
  class Object
    class Store
      class List < NATS::Utils::List
        alias_method :context, :parent

        def find(bucket)
          stream = js.streams.find("OBJ_#{bucket}")
          Store.new(context, stream, config(stream))
        rescue NATS::JetStream::StreamNotFoundError
          raise NATS::Object::StoreNotFoundError
        end

        def add(config)
          config = Store::Config.new(config)
          stream = js.streams.create(config.stream)

          Store.new(context, stream, config)
        end
        alias_method :create, :add

        def each
          js.streams.with(subject: subject).each do |stream|
            yield Store.new(context, stream, config(stream)) if store?(stream)
          end
        end

        def names
          Enumerator.new do |yielder|
            js.streams.names(subject: subject).each do |name|
              yielder << bucket(name) if store?(name)
            end
          end
        end

        private

        def js
          context.js
        end

        def subject
          "$O.*.C.>"
        end

        def config(stream)
          {
            bucket: bucket(name(stream)),
            **stream.config
          }
        end

        def name(stream)
          if stream.is_a?(String)
            stream
          else
            stream.config.name
          end
        end

        def bucket(name)
          name.delete_prefix("OBJ_")
        end

        def store?(stream)
          name(stream).start_with?("OBJ_")
        end
      end
    end
  end
end
