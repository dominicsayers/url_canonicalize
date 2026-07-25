# frozen_string_literal: true

source 'https://rubygems.org'

gemspec

group :static_code_analysis do
  gem 'rubocop', require: false
  gem 'rubocop-rake', require: false
  gem 'rubocop-rspec', require: false
end

group :test do
  gem 'rspec'
  gem 'simplecov', '~> 0.22.0'
  gem 'webmock'
end

group :build do
  gem 'gem-release', require: false
  gem 'rake', require: false
  gem 'release_ceremony', require: false
end
