# frozen_string_literal: true

module NATS
  class Object
    class Put
      class ChunksInfo
        attr_reader :size, :chunks

        def initialize
          @size = 0
          @chunks = 0
          @sha256 = Digest::SHA256.new
        end

        def published(chunk)
          @sha256 << chunk
          @size += chunk.bytesize
          @chunks += 1
        end

        def digest
          "SHA-256=#{Base64.urlsafe_encode64(@sha256.digest)}"
        end

        def to_hash
          {size: size, chunks: chunks, digest: digest}
        end
      end
    end
  end
end
