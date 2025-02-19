# frozen_string_literal: true

module NATS
  class JetStream
    class Consumer
      class List < NATS::Utils::List
        alias js parent

        def find(name)
        end

        def add(config)
        end

        def add_or_update(config)
        end
      end
    end
  end
end
