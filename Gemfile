# frozen_string_literal: true

source 'https://rubygems.org'

gemspec

group :static_code_analysis do
  gem 'rubocop', require: false
end

group :test do
  gem 'coveralls', require: false
  gem 'rspec'
  gem 'rspec_junit_formatter'
  gem 'simplecov', '~> 0.13'
  gem 'webmock'
end

local_gemfile = 'Gemfile.local'

if File.exist?(local_gemfile)
  eval(File.read(local_gemfile)) # rubocop:disable Security/Eval
end
