# frozen_string_literal: true

module NATS
  class JetStream
    class Subscription
      class Fetch < Pull
        include Enumerable

        def initialize(consumer, params = {}, &block)
          super

          @closed_cond = new_cond
        end

        def each(&block)
          synchronize do
            @handler = block
            execute

            @closed_cond.wait(config.expires)
          end

          self
        end

        private

        def closed!
          puts "Closing (#{Thread.current.object_id})"
          synchronize do
            super
            @closed_cond.signal
          end
        end

        def handle_message(message)
          synchronize do
            heartbeats.reset
          end

          handler.call(message)

          synchronize do
            messages.fetched(message)
            puts "Messages Full? = #{messages.full?} (#{Thread.current.object_id})"
            drain if messages.full?
          end
        end

        def handle_heartbeat(message)
          synchronize do
            heartbeats.reset
          end
        end

        def handle_warning(message)
          synchronize do
            error(message)
            drain
          end
        end

        def handle_error(message)
          synchronize do
            error(message)
            drain
          end
        end

        def handle_no_heartbeats
          synchronize do
            #error()
            drain
          end
        end
      end
    end
  end
end
