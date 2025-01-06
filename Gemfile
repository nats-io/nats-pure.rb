# frozen_string_literal: true

source "https://rubygems.org"

gemspec

# Rails deps
unless ENV["SKIP_RAILS"] == "true"
  gem 'rails', require: false
  gem 'sqlite3', require: false
end

# Dev deps
gem "debug", platform: :mri unless ENV["CI"]
gem 'ruby-progressbar'
eval_gemfile "gemfiles/rubocop.gemfile"

local_gemfile = ENV.fetch("LOCAL_GEMFILE") { File.expand_path("../Gemfile.local", __dir__) }

if File.exist?(local_gemfile)
  eval(File.read(local_gemfile)) # rubocop:disable Security/Eval
end
