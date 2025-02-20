# frozen_string_literal: true

module NATS
  class JetStream
    class Consumer
      class List < NATS::Utils::List
        alias js parent

        def find(name)
          response = js.api.consumer.info(name)
          Consumer.new(js, response.data.config)
        end

        def add(config)
          Consumer.new(js, config).create
        end
        alias create add

        def upsert(config)
        end
        alias add_or_update upsert
      end
    end
  end
end
