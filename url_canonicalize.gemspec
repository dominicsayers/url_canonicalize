# frozen_string_literal: true

require_relative 'lib/url_canonicalize/version'

Gem::Specification.new do |s|
  s.name          = 'url_canonicalize'
  s.version       = URLCanonicalize::VERSION
  s.authors       = ['Dominic Sayers']
  s.email         = ['dominic@sayers.cc']
  s.summary       = 'Finds the canonical version of a URL'
  s.description   = 'Rubygem that finds the canonical version of a URL by ' \
                    'providing #canonicalize methods for the String, URI::HTTP' \
                    ', URI::HTTPS and Addressable::URI classes'
  s.homepage      = 'https://github.com/dominicsayers/url_canonicalize'
  s.license       = 'MIT'

  s.required_ruby_version = '>= 3.1.0'

  # A deterministic whitelist: runtime code plus user-facing documentation.
  # Development configuration is deliberately not packaged.
  s.files = Dir.glob('lib/**/*.rb', base: __dir__).sort + %w[CHANGELOG.md LICENSE README.md SECURITY.md]
  s.require_paths = ['lib']

  s.metadata = {
    'bug_tracker_uri' => "#{s.homepage}/issues",
    'changelog_uri' => "#{s.homepage}/blob/main/CHANGELOG.md",
    'documentation_uri' => 'https://www.rubydoc.info/gems/url_canonicalize',
    'homepage_uri' => s.homepage,
    'source_code_uri' => s.homepage,
    'rubygems_mfa_required' => 'true'
  }

  s.add_dependency 'addressable', '~> 2' # To normalize URLs
  s.add_dependency 'nokogiri', '>= 1.13' # To look for <link rel="canonical" ...> in HTML
end
