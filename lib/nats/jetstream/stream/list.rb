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
          API::Iterator.new(params) do |params, streams|
            response = js.api.stream.list(params)

            response.data.streams.each do |stream|
              streams << Stream.new(js, stream.config)
            end

            response
          end
        end

        def names(params = {})
          API::Iterator.new(params) do |params, streams|
            response = js.api.stream.names(params)

            response.data.streams.each do |stream|
              streams << stream
            end

            response
          end
        end
      end
    end
  end
end
