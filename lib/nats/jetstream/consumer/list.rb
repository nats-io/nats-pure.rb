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
            stream_name: stream.config.name,
            config: config,
            action: "create"
          )

          Consumer.new(stream, response.data.config)
        end
        alias create add

        def upsert(config)
          response = js.api.consumer.create(
            stream.subject,
            stream_name: stream.config.name,
            config: config,
            action: ""
          )

          Consumer.new(stream, response.data.config)
        end
        alias add_or_update upsert

        def each(&block)
          all.each(&block)
        end

        def all(params = {})
          API::Iterator.new(params) do |params, consumers|
            response = js.api.consumer.list(stream.subject, params)

            response.data.consumers.each do |consumer|
              consumers << Consumer.new(options[:stream], consumer.config)
            end

            response
          end
        end

        def names(params = {})
          API::Iterator.new(params) do |params, consumers|
            response = js.api.consumer.list(stream.subject, params)

            response.data.consumers.each do |consumer|
              consumers << consumer
            end

            response
          end
        end

        def js
          stream.jetstream
        end
      end
    end
  end
end
