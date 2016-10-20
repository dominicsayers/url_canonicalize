source 'https://rubygems.org'

gemspec

group :test do
  gem 'rspec'
  gem 'rspec_junit_formatter'
  gem 'webmock'
  gem 'simplecov'
  gem 'coveralls', require: false
end

local_gemfile = 'Gemfile.local'

if File.exist?(local_gemfile)
  eval(File.read(local_gemfile)) # rubocop:disable Lint/Eval
end
