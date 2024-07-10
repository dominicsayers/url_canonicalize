# frozen_string_literal: true

lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'url_canonicalize/version'

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

  s.files = `git ls-files`.split($RS).grep_v(%r{^spec/})

  s.executables   = s.files.grep(%r{^bin/}) { |f| File.basename(f) }
  s.require_paths = ['lib']

  s.add_dependency 'addressable', '~> 2' # To normalize URLs
  s.add_dependency 'nokogiri', '>= 1.13' # To look for <link rel="canonical" ...> in HTML
  s.metadata['rubygems_mfa_required'] = 'true'
end
