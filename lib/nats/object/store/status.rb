# frozen_string_literal: true

module NATS
  class Object
    class Store
      class Status < NATS::Utils::Config
        # Bucket is the name of the bucket
        string :bucket

        # Description is the description supplied when creating the bucket
        string :description

        # Bucket-level metadata
        hash :metadata

        # TTL indicates how long objects are kept in the bucket
        integer :ttl

        # Storage indicates the underlying JetStream storage technology
        # used to store data
        string :storage

        # Replicas indicates how many storage replicas are kept for
        # the data in the bucket
        integer :num_replicas

        # Sealed indicates the stream is sealed and cannot be modified in any way
        bool :sealed

        # Size is the combined size of all data in the bucket including metadata,
        # in bytes
        integer :size

        # Compressed indicates if the data is compressed on disk
        bool :compressed

        # BackingStore provides details about the underlying storage.
        # Currently the only supported value is `JetStream`
        string :backing_store, default: "JetStream"

        def initialize(store)
          info = store.stream.info

          super(
            **info.config,
            bucket: store.config.bucket,
            ttl: info.config.max_age,
            size: info.state.bytes,
            compressed: info.config.compression != "none"
          )
        end
      end
    end
  end
end
