# frozen_string_literal: true

module NATS
  class JetStream
    class Message
      class Ack
        attr_reader :message, :js

        def initialize(message)
          @message = message
          @js = message.consumer.js
          @acked = false
        end

        def acked?
          @acked
        end

        def ack(params = {})
          reply(:ack, params)
        end

        def nack(params = {})
          reply(:nack, params)
        end

        def term(params = {})
          reply(:term, params)
        end

        def in_progress(params = {})
          send_reply(:in_progress, params)
        end

        private

        def reply(type, params)
          raise JetStream::MessageAckedError if acked?

          send_reply(type, params)
          @acked = true
        end

        def send_reply(type, params)
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
