# frozen_string_literal: true

module NATS
  class Object
    class Store
      class Subject
        attr_reader :store, :js

        def initialize(store)
          @store = store
          @js = store.context.js
        end

        def find(object)
          message = store.stream.messages.find(last_by_subj: subject(object))

          to_object(message)
        rescue NATS::JetStream::MessageNotFoundError
          nil
        end

        def purge(object)
          store.stream.purge(filter: subject(object))
        end

        def consume(object, options = {})
          consumer(object, options).consume do |message, pull|
            yield to_object(message), pull
          end
        end

        private

        def consumer(object, options)
          store.stream.consumers.create(
            name: consumer_name(object),
            filter_subject: subject(object),
            **options
          )
        end

        def consumer_name(object)
          "#{store.config.bucket}-#{filter(object)}-#{SecureRandom.hex}"
        end

        def filter(object)
          (object == ">") ? "all" : object
        end
      end
    end
  end
end
