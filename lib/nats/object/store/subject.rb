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
          # NATS 2.12.0 strict mode doesn't support last_by_subj field
          # Try to find the message by using the stream's last sequence
          # and working backwards (this is a workaround)
          begin
            stream_info = store.stream.info
            last_seq = stream_info.state.last_seq

            # Try to get the last few messages and find one with matching subject
            last_seq.downto([last_seq - 10, 1].max).each do |seq|
              message = store.stream.messages.find(seq: seq)
              if message.subject == subject(object)
                return to_object(message)
              end
            rescue NATS::JetStream::MessageNotFoundError, NATS::JetStream::BadRequestError
              next
            end

            nil
          rescue
            nil
          end
        rescue NATS::JetStream::MessageNotFoundError, NATS::JetStream::BadRequestError
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
