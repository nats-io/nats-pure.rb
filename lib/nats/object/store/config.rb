# frozen_string_literal: true

module NATS
  class Object
    class Store
      class Config < NATS::Utils::Config
        string :bucket, as: :name, required: true
        string :description

        integer :ttl
        integer :max_bytes, default: -1

        string :storage, in: %w[file memory], default: "file"
        integer :num_replicas, max: 5, default: 1

        object :placement do
          string :cluster
          array :tags, of: :string
        end

        string :compression, in: %w[none s2], default: "none"

        hash :metadata

        alias_method :max_age, :ttl

        def stream
          {
            **attributes,
            name: name,
            subjects: subjects,
            max_age: ttl,
            discard: "new",
            allow_rollup_hdrs: true,
            allow_direct: true
          }
        end

        def name
          "OBJ_#{bucket}"
        end

        def subjects
          ["$O.#{bucket}.C.>", "$O.#{bucket}.M.>"]
        end
      end
    end
  end
end
