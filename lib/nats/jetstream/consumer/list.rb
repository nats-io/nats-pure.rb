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
          js.api.iterator(params, stream: stream) do
            request do |params|
              js.api.consumer.list(options[:stream].subject, params)
            end

            iterate do |response, consumers|
              response.data.consumers.each do |consumer|
                consumers << Consumer.new(options[:stream], consumer.config)
              end
            end
          end
        end

        def names(params = {})
          js.api.iterator(params) do
            request do |params|
              js.api.consumer.list(options[:stream].subject, params)
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
