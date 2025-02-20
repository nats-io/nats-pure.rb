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
          iterator = Iterator.new do |stream|
            Stream.new(js, stream.config)
          end

          iterator.each(&block)
        end

        #def each
          #response = js.api.stream.list

          #until response.last?
            #response.data.streams.each do |stream|
              #yield Stream.new(js, stream.config)
            #end

            #response = js.api.stream.list(offset: response.next_page)
          #end

          #self
        #end

        def names(params = {})
        end

        def all
          map(&:itself)
        end
      end
    end
  end
end
