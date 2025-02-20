# frozen_string_literal: true

module NATS
  class JetStream
    class Consumer
      class List < NATS::Utils::List
        alias stream parent

        def find(name)
          response = js.api.consumer.info(name)
          Consumer.new(stream, response.data.config)
        end

        def add(config)
          response = js.api.consumer.create(
            stream.subject,
            stream_name: stream.name,
            config: config,
            action: "create"
          )

          Consumer.new(stream, response.data.config)
        end
        alias create add

        def upsert(config)
          response = js.api.consumer.create(
            stream.subject,
            stream_name: stream.name,
            config: config,
            action: ""
          )

          Consumer.new(stream, response.data.config)
        end
        alias add_or_update upsert

        def each
        end

        def names
        end

        def js
          stream.jetstream
        end
      end
    end
  end
end
