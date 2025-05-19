# frozen_string_literal: true

module NATS
  class JetStream
    class Message < NATS::Utils::Config
      class Ack
        include MonitorMixin

        attr_reader :message, :js

        def initialize(message)
          super()

          @message = message
          @js = message.stream.js
          @acked = false
        end

        def acked?
          synchronize { @acked }
        end

        def ack(params = {})
          ack_and_reply(:ack, params)
        end

        def nack(params = {})
          ack_and_reply(:nack, params)
        end

        def term(params = {})
          ack_and_reply(:term, params)
        end

        def in_progress(params = {})
          reply(:in_progress, params)
        end

        private

        def ack_and_reply(type, params)
          raise JetStream::MessageAckedError if acked?

          reply(type, params)
          synchronize { @acked = true }
        end

        def reply(type, params)
          js.client.request(
            message.reply,
            data(type, params),
            **params
          )
        end

        def data(type, params)
          case type
          when :ack
            "+ACK"
          when :nack
            nack_data(params)
          when :term
            term_data(params)
          when :in_progress
            "+WPI"
          end
        end

        def nack_data(params)
          if params[:delay]
            "-NACK #{params.slice(:delay).to_json}"
          else
            "-NACK"
          end
        end

        def term_data(params)
          if params[:reason]
            "+TERM #{params[:reason]}"
          else
            "+TERM"
          end
        end
      end
    end
  end
end
