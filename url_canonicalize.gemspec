# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'url_canonicalize/version'

Gem::Specification.new do |s|
  s.name          = 'url_canonicalize'
  s.version       = URLCanonicalize::VERSION
  s.authors       = ['Dominic Sayers']
  s.email         = ['developers@xenapto.com']
  s.summary       = 'Finds the canonical version of a URL'
  s.description   = 'Rubygem that provides #canonicalize methods for the String, URI::HTTP, URI::HTTPS and '\
                    'Addressable::URI classes'
  s.homepage      = 'https://github.com/Xenapto/url_canonicalize'
  s.license       = 'MIT'

  s.files         = `git ls-files -z`.split("\x0")
  s.executables   = s.files.grep(%r{^bin/}) { |f| File.basename(f) }
  s.test_files    = s.files.grep(%r{^(test|spec|features)/})
  s.require_paths = ['lib']

  s.add_dependency 'addressable', '~> 0'

  s.add_development_dependency 'rake', '~> 11'
  s.add_development_dependency 'rspec', '~> 3'
  s.add_development_dependency 'rspec_junit_formatter', '~> 0'
  s.add_development_dependency 'gem-release', '~> 0'
  s.add_development_dependency 'simplecov', '~> 0'
  s.add_development_dependency 'coveralls', '~> 0'
  #- s.add_development_dependency 'vcr', '~> 2'
  #- s.add_development_dependency 'webmock', '~> 1'
  s.add_development_dependency 'rubocop', '~> 0'
  s.add_development_dependency 'listen', '~> 3.0', '< 3.1' # Dependency of guard, 3.1 requires Ruby 2.2+
  s.add_development_dependency 'guard', '~> 2'
  s.add_development_dependency 'guard-rspec', '~> 4'
  s.add_development_dependency 'guard-rubocop', '~> 1'
end
