# frozen_string_literal: true

def be_config(config)
  to_have_attributes(config)
end

def to_have_attributes(config)
  case config
  when Hash
    object = config.each_with_object({}) do |(key, value), hash|
      hash[key] = to_have_attributes(value)
    end

    have_attributes(object)
  when Array
    config.map { |item| to_have_attributes(item) }
  else
    config
  end
end
