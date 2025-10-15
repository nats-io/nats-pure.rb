# frozen_string_literal: true

module NATS
  class Object
    class Update
      class Meta < NATS::Utils::Config
        string :name, as: :name
        string :description

        hash :headers
        hash :metadata

        attr_reader :info

        def initialize(object, values)
          validate(values)

          @info = object.info.dup

          schema.each do |name, option|
            value =
              if values.has_key?(name)
                values[name]
              else
                info[name]
              end

            set(option, value)
          end
        end

        def changed?(key)
          self[key] && self[key] != info[key]
        end
      end
    end
  end
end
