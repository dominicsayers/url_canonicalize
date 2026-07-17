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

Options can be passed to the module API or any of the `canonicalize` extension
methods:

```ruby
URLCanonicalize.fetch(
  'https://example.com/article',
  total_timeout: 10,
  max_body_bytes: 512_000
)

'https://example.com/article'.canonicalize(total_timeout: 10)
```

## Security and limits

URLCanonicalize treats every fetched URL as untrusted, including redirect and
`rel="canonical"` destinations. Before connecting, it resolves the host,
rejects the destination if any DNS answer is loopback, private, link-local,
multicast, unspecified, reserved or otherwise not publicly routable, and pins
the connection to the validated address. URLs containing user information are
rejected. HTTPS always uses peer certificate and hostname verification; there
is no option to disable TLS verification.

IPv6 validation is fail-closed: only prefixes currently allocated in IANA's
global-unicast registry are eligible, with special-purpose ranges excluded.

Environment HTTP proxies are deliberately disabled because proxy-side DNS
resolution would bypass destination validation. Ports `80` and `443` are the
only ports allowed by default.

The default resource limits are:

- 30 seconds for the complete canonicalization operation, across every hop;
- 8 seconds to open a connection, 15 seconds to read and 8 seconds to write;
- 1 MiB for a buffered response body;
- 10 followed hops, shared between redirects and followed canonical links.

Only successful GET responses with `text/html`, `application/xhtml+xml`,
`application/xml` or `text/xml` media types are buffered. Media-type casing and
parameters such as `charset` are accepted. Other response bodies are drained
without being retained, and only HTML/XHTML responses are parsed for canonical
link elements.

All limits can be made stricter, and additional ports can be explicitly
allowed:

```ruby
URLCanonicalize.fetch(
  'https://example.com:8443/article',
  allowed_ports: [443, 8443],
  max_body_bytes: 256_000,
  total_timeout: 5,
  open_timeout: 2,
  read_timeout: 3,
  write_timeout: 2,
  max_redirects: 5
)
```

Private-network fetching is available only as an explicit escape hatch for
trusted URLs:

```ruby
URLCanonicalize.fetch(
  'http://intranet.example.test',
  allow_private_networks: true
)
```

Enabling `allow_private_networks` relaxes the SSRF protection. It still pins the
resolved address and enforces the user-information and port policies.

Policy violations raise `URLCanonicalize::Exception::Security`, oversized
responses raise `URLCanonicalize::Exception::ResponseTooLarge`, and the overall
deadline raises `URLCanonicalize::Exception::Timeout`. Other socket and TLS
failures continue to surface as `URLCanonicalize::Exception::Failure`.

## How URLs are followed

Every hop starts with a `HEAD` request. If the response carries no canonical
hint in its headers, the request is retried as a `GET` so the HTML can be
inspected. A `HEAD` request rejected with `403 Forbidden`,
`405 Method Not Allowed` or `501 Not Implemented` is also retried once as a
`GET`, because some servers refuse `HEAD` requests outright; an unsuccessful
`GET` is not retried.

All redirect responses (`301`, `302`, `303`, `307` and `308`) are followed
through their `Location` header. A redirection without a usable `Location` is
treated as a failure.

Canonical URLs are discovered from `Link` response headers whose `rel` tokens
include `canonical` (RFC 8288), and from `<link rel="canonical">` elements in
the HTML `<head>`, matched case-insensitively. Header targets resolve against
the request URL; HTML targets resolve against the document base URL, honouring
any `<base href>` element. Absolute, protocol-relative, root-relative,
path-relative and query-only references are all resolved per RFC 3986, and
only `http` or `https` results are followed.

Redirects and followed canonical links share a single visited-URL set and a
single hop budget (`max_redirects`), so cycles and over-long chains always
terminate. A cycle or exhausted budget returns the last successfully fetched
response if there is one, and raises `URLCanonicalize::Exception::Redirect`
otherwise. When a failure is caused by an underlying exception, that exception
is preserved as the `cause` of the raised
`URLCanonicalize::Exception::Failure`.

## More Information

URLCanonical follows HTTP redirects and also looks for `rel="canonical"` hints
in both the HTTP headers and the `<head>` section of the response HTML. The URL
it returns will be both normalized and canonical. The intention is that
whatever variant of a URL is supplied the result will always be the same. The
intended use case is for applications that need to dedupe a list of URLs, for
instance to check if a new URL is already present in a list. If the list is
built from canonicalized URLs then the resulting set will have fewer URLs that
point to the same ultimate resource.
