# frozen_string_literal: true

begin
  require "rails"
  require "nats/io/rails"
  require "rails/application"
  require "active_record"
  require "active_record/railtie"
rescue LoadError
end

require "spec_helper"

describe "Rails integration", :rails do
  before(:all) do
    skip "rails not installed" if !defined?(Rails)
    @serverctl = NatsServerControl.new.tap { |s| s.start_server(true) }
  end

  after(:all) do
    @serverctl&.kill_server
  end

  around do |example|
    old_database_url = ENV["DATABASE_URL"]
    ENV["DATABASE_URL"] ||= "sqlite3::memory:?db_pool_size=#{db_pool_size}&checkout_timeout=#{checkout_timeout}"
    example.run
  ensure
    ENV["DATABASE_URL"] = old_database_url
  end

  let(:db_pool_size) { 5 }
  let(:checkout_timeout) { 2 }

  let!(:application) do
    stub_const("TestApp", Class.new(Rails::Application) do
      config.load_defaults Rails::VERSION::STRING.split(".").take(2).join(".")
      config.eager_load = true
      config.active_record.legacy_connection_handling = false if ActiveRecord::VERSION::STRING < "7.0.0"
    end).tap { Rails.application.initialize! }
  end

  it "should give back implicitly checked out database connections" do
    nats = NATS.connect

    queue = Queue.new
    (db_pool_size * 2).times do |i|
      nats.subscribe("ar-test") do |msg|
        ActiveRecord::Base.connection.execute("SELECT 1") # Implicitly checkout connection
        queue << i
      end
    end
    nats.flush

    nats.publish("ar-test", "hello")
    nats.drain

    # Wait for all subscriptions to be processed
    finished = false
    nats.on_close { finished = true }
    sleep 0.1 until finished

    expect { ActiveRecord::Base.connection.execute("SELECT 1") }.to_not raise_error
    expect(queue.size).to eql(db_pool_size * 2)
  end
end
