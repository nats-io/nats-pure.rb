# frozen_string_literal: true

module NATS
  class Service
    module Validator
      REGEX = {
        name: /[A-Za-z0-9\-_]+$/,
        version: /^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(?:-((?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*)(?:\.(?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*))*))?(?:\+([0-9a-zA-Z-]+(?:\.[0-9a-zA-Z-]+)*))?$/,
        subject: /^[^ >]*[>]?$/,
        queue: /^[^ >]*[>]?$/
      }.freeze

      class << self
        def validate(values)
          raise InvalidNameError unless valid?(values, :name)
          raise InvalidVersionError unless valid?(values, :version)
          raise InvalidSubjectError unless valid?(values, :subject) || nil?(values, :subject)
          raise InvalidQueueError unless valid?(values, :queue) || nil?(values, :queue)
        end

        def valid?(values, key)
          !values.has_key?(key) || values[key] =~ REGEX[key]
        end

        def nil?(values, key)
          values.has_key?(key) && values[key].nil?
        end
      end
    end
  end
end
