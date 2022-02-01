# SimpleCov
unless ENV['NO_SIMPLECOV']
  require 'simplecov'
  require 'coveralls'

  if ENV['CIRCLE_ARTIFACTS']
    dir = File.join('..', '..', '..', ENV['CIRCLE_ARTIFACTS'], 'coverage')
    SimpleCov.coverage_dir(dir)
  end

  SimpleCov.start { add_filter '/spec/' }
  Coveralls.wear! if ENV['COVERALLS_REPO_TOKEN'] && Gem::Version.new(RUBY_VERSION) < Gem::Version.new('3.1')
end

# Webmock
require 'webmock/rspec'
WebMock.disable_net_connect!(allow_localhost: true)

# Specs
require 'url_canonicalize'

RSpec.configure do |config|
  config.run_all_when_everything_filtered = true
  config.order = 'random'
end
