# frozen_string_literal: true

begin
  require "debug" unless ENV["CI"]
rescue LoadError
end

if ENV["CI"]
  require "rspec/retry"
end

ENV["RAILS_ENV"] = "test"

require "nats-pure"
require "nats/io/jetstream"
require "nkeys"

require "fileutils"
require "tempfile"
require "monitor"
require "openssl"
require "erb"
require "timecop"

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

  config.filter_run_excluding(tls_verify_hostname: true) if defined?(JRUBY_VERSION)

  if Process.respond_to?(:fork)
    config.after do
      # Mark all clients as closed to avoid reconnects in fork tests
      NATS::Client.const_get(:INSTANCES).each do |client|
        client.close unless client.closed?
      end
    end
  end

  if ENV["CI"]
    # rspec-retry
    config.verbose_retry = true
    config.display_try_failure_messages = true
    config.default_retry_count = 5
  end
end
