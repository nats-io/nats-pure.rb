# frozen_string_literal: true

module NATS
  class Object
    class Get
      class Options < NATS::Utils::Config
        bool :show_deleted, default: false

        # symbol :as
        string :path

        bool :async, default: false
        integer :timeout

        attr_reader :as

        def initialize(values)
          super
          @as = values[:as]
        end

        def io
          case as
          when :string
            StringIO.new
          when :file
            path ? File.new(path, "w") : Tempfile.new
          when nil
            Tempfile.new
          else
            as
          end
        end

        def wait?
          !async
        end

        def as_string?
          as == :string
        end

        def lazy?
          as.nil?
        end
      end
    end
  end
end
