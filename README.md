# URLCanonicalize

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
Addressable::URI.canonicalize('http://www.twitter.com') # => #<Addressable::URI:0x43c9d90 URI:https://twitter.com/>
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
