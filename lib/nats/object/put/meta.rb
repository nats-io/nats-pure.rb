# frozen_string_literal: true

module NATS
  class Object
    class Put
      class Meta < NATS::Utils::Config
        string :name, as: :name, required: true
        string :description

        hash :headers
        hash :metadata

        object :options, default: {} do
          integer :max_chunk_size, default: 128 * 1024
        end

        string :nuid
        io :data
      end
    end
  end
end
