# URLCanonicalize
[![Gem Version](https://badge.fury.io/rb/url_canonicalize.svg)](https://rubygems.org/gems/url_canonicalize)
[![Gem downloads](https://img.shields.io/gem/dt/url_canonicalize.svg)](https://rubygems.org/gems/url_canonicalize)
[![Build status](https://img.shields.io/circleci/project/dominicsayers/url_canonicalize/master.svg)](https://circleci.com/gh/dominicsayers/url_canonicalize)
[![Maintainability](https://api.codeclimate.com/v1/badges/1f92f784d12741a942ec/maintainability)](https://codeclimate.com/github/dominicsayers/url_canonicalize/maintainability)
[![Coverage Status](https://coveralls.io/repos/github/dominicsayers/url_canonicalize/badge.svg?branch=master)](https://coveralls.io/github/dominicsayers/url_canonicalize?branch=master)
[![Dependency Status](https://dependencyci.com/github/dominicsayers/url_canonicalize/badge)](https://dependencyci.com/github/dominicsayers/url_canonicalize)
[![Security](https://hakiri.io/github/dominicsayers/url_canonicalize/master.svg)](https://hakiri.io/github/dominicsayers/url_canonicalize/master)
[![Codacy Badge](https://api.codacy.com/project/badge/Grade/1b8d50209b8c41a2b8200e25a63d57b3)](https://www.codacy.com/app/dominicsayers/url_canonicalize)

URLCanonicalize is a Ruby gem that finds the canonical version of a URL. It
provides `canonicalize` methods for the String, URI::HTTP, URI::HTTPS and
Addressable::URI classes.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'url_canonicalize'
```

## Usage

```ruby
'http://www.twitter.com'.canonicalize # => 'https://twitter.com/'

URI('http://www.twitter.com').canonicalize # => #<URI::HTTP:0x00000008767908 URL:https://twitter.com/>

Addressable::URI.canonicalize('http://www.twitter.com') # => #<Addressable::URI:0x43c9 URI:https://twitter.com/>
```

## More Information

URLCanonical follows HTTP redirects and also looks for `rel="canonical"` hints
in both the HTTP headers and the `<head>` section of the response HTML. The URL
it returns will be both normalized and canonical. The intention is that
whatever variant of a URL is supplied the result will always be the same. The
intended use case is for applications that need to dedupe a list of URLs, for
instance to check if a new URL is already present in a list. If the list is
built from canonicalized URLs then the resulting set will have fewer URLs that
point to the same ultimate resource.
