# frozen_string_literal: true

source 'https://rubygems.org'

gemspec

group :static_code_analysis do
  gem 'rubocop', require: false
  gem 'rubocop-rspec', require: false
end

group :test do
  gem 'coveralls', require: false
  gem 'rspec'
  gem 'rspec_junit_formatter'
  gem 'simplecov', '~> 0.13'
  gem 'webmock'
end

group :build do
  gem 'gem-release', require: false
end
