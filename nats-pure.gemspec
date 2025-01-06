# frozen_string_literal: true

# Copyright 2016-2022 The NATS Authors
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

require_relative 'lib/nats/io/version'

Gem::Specification.new do |s|
  s.name = 'nats-pure'
  s.version = NATS::IO::VERSION
  s.summary = 'NATS is an open-source, high-performance, lightweight cloud messaging system.'
  s.homepage = 'https://nats.io'
  s.description = 'NATS is an open-source, high-performance, lightweight cloud messaging system.'
  s.licenses = ['Apache-2.0']

  s.authors = ['Waldemar Quevedo']
  s.email = ['wally@synadia.com']

  s.metadata = {
    "bug_tracker_uri" => "https://github.com/nats-io/nats-pure.rb/issues",
    "changelog_uri" => "https://github.com/nats-io/nats-pure.rb/blob/master/CHANGELOG.md",
    "documentation_uri" => "https://github.com/nats-io/nats-pure.rb",
    "homepage_uri" => "https://github.com/nats-io/nats-pure.rb",
    "source_code_uri" => "https://github.com/nats-io/nats-pure.rb"
  }

  s.required_ruby_version = ">= 3.0"

  s.require_paths = ['lib']

  s.files = Dir.glob("lib/**/*.rb") + Dir.glob("sig/**/*.rbs") + %w[README.md LICENSE CHANGELOG.md]

  s.add_dependency "concurrent-ruby", "~> 1.0"
  # Default Ruby gems
  s.add_dependency "uri"
  s.add_dependency "securerandom"
  s.add_dependency "json"
  s.add_dependency "base64"

  # Optional deps
  s.add_development_dependency "nkeys"
  s.add_development_dependency "websocket"

  s.add_development_dependency "bundler", ">= 1"
  s.add_development_dependency "rake", ">= 13.0"
  s.add_development_dependency "rspec", ">= 3.5"
  s.add_development_dependency "resolv-replace"
end
