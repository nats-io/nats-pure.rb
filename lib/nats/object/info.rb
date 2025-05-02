# frozen_string_literal: true

module NATS
  class Object
    class Info < NATS::Utils::Config
      string :name
      string :description

      hash :headers, default: {}
      hash :metadata, default: {}

      object :options do
        object :link do
          string :bucket
          string :name
        end

        integer :max_chunk_size, default: 128 * 1024
      end

      string :bucket
      string :nuid

      integer :size, default: 0
      integer :chunks, default: 0
      string :digest, default: ""

      bool :deleted, default: false
      alias_method :deleted?, :deleted

      attr_reader :message, :mtime
      alias_method :mod_time, :mtime

      def initialize(values)
        super

        @message = values[:message]
        @mtime = values[:mtime] || message&.time || Time.now
      end

      def update(values)
        super
        @mtime = values[:mtime] if values.has_key?(:mtime)

        self
      end

      def link
        options&.link
      end

      def link?
        !!options&.link
      end

      def no_data?
        size.zero?
      end

      def raw_digest
        Base64.urlsafe_decode64(digest.delete_prefix("SHA-256="))
      rescue
        raise InvalidDigestError
      end
    end
  end
end
