# frozen_string_literal: true

require 'simplecov'
require 'webmock/rspec'

# SimpleCov must start before the code under test is required so every lib
# file is tracked from its first load; NO_SIMPLECOV skips coverage entirely
unless ENV['NO_SIMPLECOV']
  SimpleCov.start do
    add_filter '/spec/'
    enable_coverage :branch

    # Enforced only on full CI runs so partial local runs (a single spec file)
    # do not fail on coverage they never attempted
    minimum_coverage line: 100, branch: 100 if ENV['CI']
  end
end

require 'url_canonicalize'

WebMock.disable_net_connect!(allow_localhost: true)

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
