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
          Stream.new(js, config).create
        end
        alias create add

        def each
          response = js.api.stream.list

          until response.last?
            response.data.streams.each do |stream|
              yield Stream.new(js, stream.config)
            end

            response = js.api.stream.list(offset: response.next_page)
          end

          self
        end

        def all
          map(&:itself)
        end
      end
    end
  end
end
