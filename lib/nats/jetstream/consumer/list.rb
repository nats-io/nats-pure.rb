# frozen_string_literal: true

module NATS
  class JetStream
    class Consumer
      class List < NATS::Utils::List
        alias_method :stream, :parent

        def find(name)
          response = js.api.consumer.info("#{stream.subject}.#{name}")
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
        alias_method :create, :add

        def upsert(config)
          response = js.api.consumer.create(
            stream.subject,
            stream_name: stream.config.name,
            config: config,
            action: ""
          )

          Consumer.new(stream, response.data.config)
        end
        alias_method :add_or_update, :upsert

        def each(&block)
          all.each(&block)
        end

        def all(params = {})
          js.api.iterator(params) do |params, consumers|
            response = js.api.consumer.list(stream.subject, params)

            response.data.consumers.each do |consumer|
              consumers << Consumer.new(stream, consumer.config)
            end

            response
          end
        end

        def names(params = {})
          js.api.iterator(params) do |params, consumers|
            response = js.api.consumer.names(stream.subject, params)

            response.data.consumers.each do |consumer|
              consumers << consumer
            end

            response
          end
        end

        private

        def js
          stream.jetstream
        end
      end
    end
  end
end
