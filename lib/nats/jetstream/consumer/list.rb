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

        def each(&block)
          all.each(&block)
        end

        def all(params = {})
          js.api.iterate(params) do
            request do |params|
              js.api.consumer.list(params)
            end

            iterate do |response, consumers|
              response.data.consumers.each do |consumer|
                consumers << Consumer.new(stream, consumer.config)
              end
            end
          end
        end

        def names(params = {})
          js.api.iterate(params) do
            request do |params|
              js.api.stream.names(params)
            end

            iterate do |response, consumers|
              response.data.consumers.each do |consumer|
                consumers << consumer
              end
            end
          end
        end

        def js
          stream.jetstream
        end
      end
    end
  end
end
