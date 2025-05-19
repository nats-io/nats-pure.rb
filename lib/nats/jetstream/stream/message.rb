# frozen_string_literal: true

require "base64"

module NATS
  class JetStream
    class Stream
      class Message < NATS::Utils::Config
        attr_reader :stream, :js

        string :subject
        hash :header, default: {}
        string :data

        integer :sequence
        time :time

        alias_method :seq, :sequence

        def initialize(stream, message)
          @stream = stream
          @js = stream.js

          super(
            subject: message.subject,
            header: parse_header(message),
            data: Base64.decode64(message.data),
            sequence: message.seq,
            time: message.time
          )
        end

        def delete
          js.api.stream.msg.delete(stream.subject, seq: sequence).success?
        end

        def inspect
          "#<#{self.class} @subject=#{subject}, @header=#{header}, @data=#{data}, @sequence=#{sequence}, @time=#{time}>"
        end
        alias_method :to_s, :inspect

        private

        def parse_header(message)
          return unless message.hdrs

          header = Base64.decode64(message.hdrs)
          js.client.send(:process_hdr, header)
        end

        class List
          attr_reader :js, :stream

          def initialize(stream)
            @stream = stream
            @js = stream.js
          end

          def find(params)
            response = js.api.stream.msg.get(stream.subject, params)
            Stream::Message.new(stream, response.data.message)
          end
        end
      end
    end
  end
end
