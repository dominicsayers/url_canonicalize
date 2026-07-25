# URLCanonicalize
[![Gem Version](https://img.shields.io/gem/v/url_canonicalize.svg)](https://rubygems.org/gems/url_canonicalize)
[![Gem downloads](https://img.shields.io/gem/dt/url_canonicalize.svg)](https://rubygems.org/gems/url_canonicalize)
[![Test](https://github.com/dominicsayers/url_canonicalize/actions/workflows/test.yml/badge.svg?branch=main)](https://github.com/dominicsayers/url_canonicalize/actions/workflows/test.yml)
[![CodeQL](https://github.com/dominicsayers/url_canonicalize/actions/workflows/codeql-analysis.yml/badge.svg?branch=main)](https://github.com/dominicsayers/url_canonicalize/actions/workflows/codeql-analysis.yml)
[![Quality gate status](https://sonarcloud.io/api/project_badges/measure?project=dominicsayers_url_canonicalize&metric=alert_status)](https://sonarcloud.io/summary/new_code?id=dominicsayers_url_canonicalize)

URLCanonicalize is a Ruby gem that finds the canonical version of a URL. It
provides a configurable client API, and optional `canonicalize` extension
methods for the String, URI::HTTP, URI::HTTPS and Addressable::URI classes.

Ruby 3.3 or later is required.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'url_canonicalize'
```

## Usage

The primary API is a reusable client. Its options are validated and frozen at
construction, so one client can be shared safely between threads:

```ruby
client = URLCanonicalize::Client.new(
  total_timeout: 10,
  max_redirects: 8,
  max_body_bytes: 512_000
)

client.canonicalize('http://www.twitter.com') # => 'https://twitter.com/'
```

For one-off calls the module methods accept the same options and build a
client internally:

```ruby
URLCanonicalize.canonicalize('http://www.twitter.com') # => 'https://twitter.com/'
URLCanonicalize.fetch('http://www.twitter.com')        # => #<URLCanonicalize::Result ...>
```

`canonicalize` returns the canonical URL as a string. `fetch` returns an
immutable `URLCanonicalize::Result` with:

- `url` — the canonical URL;
- `response` — the `Net::HTTPResponse` that confirmed it;
- `html` — the parsed Nokogiri document when the response was HTML;
- `chain` — the request chain: each hop's URL and how it was discovered
  (`:initial`, `:redirect` or `:canonical_link`);
- `source` — how the final URL was discovered.

### Configuration

Beyond the security limits described below, the client accepts:

- `headers` — the request headers to send (replaces the default browser-like
  `User-Agent` and `Accept-Language`);
- `logger` — any object responding to `debug`; each request and discovered
  canonical URL is logged. Nothing is logged by default;
- `transport` — anything responding to `call(uri, options)` and returning a
  `Net::HTTP`-compatible connection. The default transport resolves and
  validates the destination address (see below) and configures TLS and
  timeouts. Tests can inject a fake transport to avoid the network entirely;
  a custom resolver can be injected with
  `URLCanonicalize::Transport.new(resolver: ...)`.

### Core-class extensions

The core-class extensions are opt-in. Requiring `url_canonicalize/core_ext`
extends `String`, `URI::HTTP`, `URI::HTTPS` and `Addressable::URI` with a
`canonicalize` method:

```ruby
require 'url_canonicalize/core_ext'

'http://www.twitter.com'.canonicalize # => 'https://twitter.com/'

URI('http://www.twitter.com').canonicalize # => #<URI::HTTP:0x00000008767908 URL:https://twitter.com/>

Addressable::URI.canonicalize('http://www.twitter.com') # => #<Addressable::URI:0x43c9 URI:https://twitter.com/>

'https://example.com/article'.canonicalize(total_timeout: 10)
```

Requiring `url_canonicalize` alone no longer patches any core class: if you
relied on the extensions, add the extra require.

## Normalization and canonicalization

URLCanonicalize distinguishes two operations:

- **Normalization** is syntactic: rewriting a URL into its RFC 3986 normal
  form without any network access. Parsing and reference resolution use
  Ruby's `URI` (strict); normalization uses `Addressable::URI#normalize`.
- **Canonicalization** is discovery: fetching the URL, following redirects
  and server-declared canonical links, and returning the normalized final
  URL.

Every URL is processed in this order:

1. The input is stripped of surrounding whitespace and parsed. A leading
   `scheme:` token is honored; an input without one is treated as a host
   name and given `http://`. A colon elsewhere in the URL does not suppress
   the default scheme. Non-HTTP(S) schemes raise
   `URLCanonicalize::Exception::URI`.
2. The URL is normalized (see below) and fetched with a `HEAD` request,
   retried as `GET` where the server rejects `HEAD`.
3. Redirects (any `3xx` with a usable `Location`, temporary or permanent)
   are followed. The `Location` value is resolved against the request URL
   per RFC 3986, so absolute, protocol-relative, root-relative,
   path-relative and query-only forms all work.
4. On a successful response, a canonical link is looked for in the `Link`
   response header first, then in the HTML `<link rel="canonical">` element;
   **the header wins when they conflict**. HTML links resolve against the
   document's `<base href>` when one is declared, otherwise against the
   request URL.
5. A declared canonical URL is not trusted blindly: it is fetched and
   validated itself. If fetching it fails, the declared canonical URL is
   still returned, confirmed by the response that declared it.
6. Redirects and followed canonical links share one hop budget and one
   visited-URL set, so cycles and over-long chains terminate
   deterministically. The returned URL is always normalized.

Normalization makes these changes and no others:

| Component | Rule |
| --- | --- |
| Scheme and host | Lowercased |
| Internationalized host | Converted to punycode (`xn--…`) |
| Default port (`:80`/`:443`) | Removed; other ports preserved |
| Dot segments (`/./`, `/../`) | Resolved |
| Percent-encoding | Uppercase hex; unreserved characters decoded; invalid characters encoded |
| Empty path | Replaced by `/` |
| Trailing slash | Preserved (`/a/` and `/a` stay distinct) |
| Query string | Preserved verbatim — parameters are never reordered or dropped |
| Fragment (`#…`) | Stripped — fragments are client-side state |
| Userinfo (`user:pass@`) | Rejected as a security error at fetch time |

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

## Errors

All errors raised by the gem are subclasses of `URLCanonicalize::Exception`,
so `rescue URLCanonicalize::Exception` catches everything below:

| Exception | Raised when |
| --------- | ----------- |
| `Exception::URI` | the URL cannot be parsed, or is not `http`/`https` |
| `Exception::Security` | a destination violates the SSRF, userinfo or port policy |
| `Exception::Redirect` | a redirect or canonical-link chain loops or exceeds `max_redirects` |
| `Exception::Timeout` | the operation exceeds `total_timeout` |
| `Exception::ResponseTooLarge` | a response body exceeds `max_body_bytes` |
| `Exception::Failure` | the request fails (network error, TLS failure or unsuccessful HTTP status) |

When a failure wraps an underlying exception, the original is available as the
raised error's `cause`.

## Contributing and security

Development and release instructions are in
[CONTRIBUTING.md](CONTRIBUTING.md). Please report vulnerabilities privately as
described in [SECURITY.md](SECURITY.md), not through public issues.

## More Information

URLCanonical follows HTTP redirects and also looks for `rel="canonical"` hints
in both the HTTP headers and the `<head>` section of the response HTML. The URL
it returns will be both normalized and canonical. The intention is that
whatever variant of a URL is supplied the result will always be the same. The
intended use case is for applications that need to dedupe a list of URLs, for
instance to check if a new URL is already present in a list. If the list is
built from canonicalized URLs then the resulting set will have fewer URLs that
point to the same ultimate resource.
