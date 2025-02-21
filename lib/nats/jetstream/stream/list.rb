# frozen_string_literal: true

module NATS
  class JetStream
    class Stream
      class List < NATS::Utils::List
        alias js parent

        def find(name)
          response = js.api.stream.info(name)
          Stream.new(js, response.data.config)
        end

        def add(config)
          config = Stream::Config.new(config)
          response = js.api.stream.create(config.name, config)

          Stream.new(js, response.data.config)
        end
        alias create add

        def each(&block)
          all.each(&block)
        end

        def all(params = {})
          js.api.iterator(params) do
            request do |params|
              api.stream.list(params)
            end

            iterate do |response, streams|
              response.data.streams.each do |stream|
                streams << Stream.new(js, stream.config)
              end
            end
          end
        end

        def names(params = {})
          js.api.iterator(params) do
            request do |params|
              api.stream.names(params)
            end

            iterate do |response, streams|
              response.data.streams.each do |stream|
                streams << stream
              end
            end
          end
        end
      end
    end
  end
end
