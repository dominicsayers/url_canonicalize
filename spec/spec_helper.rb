unless ENV['NO_SIMPLECOV']
  require 'simplecov'

  if ENV['CIRCLE_ARTIFACTS']
    dir = File.join('..', '..', '..', ENV['CIRCLE_ARTIFACTS'], 'coverage')
    SimpleCov.coverage_dir(dir)
  end

  SimpleCov.start { add_filter '/spec/' }
end

require 'url_canonicalize'

RSpec.configure do |config|
  config.run_all_when_everything_filtered = true
  config.order = 'random'
end
