# frozen_string_literal: true

begin
  require "debug" unless ENV["CI"]
rescue LoadError
end

ENV["RAILS_ENV"] = "test"

require "nats-pure"
require "nats/io/jetstream"
require "nkeys"

require "tempfile"
require "monitor"

Dir["#{File.dirname(__FILE__)}/support/**/*.rb"].sort.each { |f| require f }

RSpec.configure do |config|
  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.example_status_persistence_file_path = "tmp/rspec_examples.txt"
  config.filter_run :focus
  config.run_all_when_everything_filtered = true

  config.order = :random
  Kernel.srand config.seed

  if Process.respond_to?(:fork)
    config.after(:each) do
      # Mark all clients as closed to avoid reconnects in fork tests
      NATS::Client::const_get(:INSTANCES).each do |client|
        client.close unless client.closed?
      end
    end
  end
end
