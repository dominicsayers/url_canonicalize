# frozen_string_literal: true

# SimpleCov
unless ENV['NO_SIMPLECOV']
  require 'simplecov'

  SimpleCov.start do
    add_filter '/spec/'
    enable_coverage :branch

    # Enforced only on full CI runs so partial local runs (a single spec file)
    # do not fail on coverage they never attempted
    minimum_coverage line: 100, branch: 100 if ENV['CI']
  end
end

# Webmock
require 'webmock/rspec'
WebMock.disable_net_connect!(allow_localhost: true)

# Specs
require 'url_canonicalize'

# Set an environment variable for the duration of a block, restoring the
# original value afterwards so no example leaks environment state
module EnvHelper
  def with_env(key, value)
    original = ENV.fetch(key, nil)
    ENV[key] = value
    yield
  ensure
    original.nil? ? ENV.delete(key) : ENV[key] = original
  end
end

RSpec.configure do |config|
  config.include EnvHelper
  config.run_all_when_everything_filtered = true
  config.order = :random
  Kernel.srand config.seed
end
