# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed

- Replace the `bin/release` scripts with the
  [`release_ceremony`](https://github.com/dominicsayers/release_ceremony) gem
  they were extracted into; the release commands are now
  `bundle exec release_ceremony prepare|publish VERSION`

## [1.0.2] - 2026-07-24

### Fixed

- Add `rake` to the development bundle so the `rake build` release check can
  run ([#204](https://github.com/dominicsayers/url_canonicalize/pull/204))

### Changed

- Announce each step of `bin/release/prepare` as it starts so the command
  shows progress instead of appearing to hang
  ([#206](https://github.com/dominicsayers/url_canonicalize/pull/206))
- Update the `ruby/setup-ruby` CI action to v1.321.0
  ([#205](https://github.com/dominicsayers/url_canonicalize/pull/205))

## [1.0.1] - 2026-07-22

### Security

- Verify TLS certificates and hostnames, block unsafe destinations at every
  hop, pin DNS results, restrict ports, bound response bodies and enforce an
  overall deadline
  ([#184](https://github.com/dominicsayers/url_canonicalize/issues/184))

### Fixed

- Correct the redirect and canonical-link HTTP state machine: follow all
  redirect responses consistently, bound redirect and canonical-link chains
  with one visited-URL set and one hop budget, parse `Link` headers properly,
  resolve relative references per RFC 3986, match HTML canonical links
  case-insensitively against the document base URL, replace host-specific HEAD
  behavior with a generic HEAD-to-GET fallback and preserve underlying error
  causes ([#185](https://github.com/dominicsayers/url_canonicalize/issues/185))

### Changed

- Refresh the test and coverage strategy: replace `coveralls-ruby` with a
  current SimpleCov release, enforce 100% line and branch coverage on CI,
  test redirect and canonical-link behavior deterministically at the HTTP
  boundary and isolate environment changes in every example
  ([#189](https://github.com/dominicsayers/url_canonicalize/issues/189))
- Refresh gem packaging and release automation: package a deterministic
  whitelist of runtime files, verify the built gem in CI, add full RubyGems
  metadata, publish through RubyGems Trusted Publishing from a tag-triggered
  workflow, and document security reporting and release procedures
  ([#190](https://github.com/dominicsayers/url_canonicalize/issues/190))

## [1.0.0] - 2024-01-27

### Changed

- Require Ruby 3.1 or later
- Adapt to the behavior of current `uri` gem releases
- Update development dependencies and CI configuration

## [0.2.1] - 2022-02-01

### Changed

- Require a recent Nokogiri version
- Update development dependencies, RuboCop configuration and CI configuration

## [0.2.0] - 2018-06-30

### Added

- Return a Nokogiri XML document from a successful response when requested
  ([#5](https://github.com/dominicsayers/url_canonicalize/issues/5))

### Changed

- Require a secure Nokogiri version

## 0.1.15 and earlier

Releases from 0.0.1 (2016-10-20) to 0.1.15 (2017-03-14) predate this
changelog format. Their history is available from the
[v0.1.15 tag](https://github.com/dominicsayers/url_canonicalize/releases/tag/v0.1.15)
and the
[commit log](https://github.com/dominicsayers/url_canonicalize/commits/v0.1.15).

[Unreleased]: https://github.com/dominicsayers/url_canonicalize/compare/v1.0.2...HEAD
[1.0.2]: https://github.com/dominicsayers/url_canonicalize/compare/v1.0.1...v1.0.2
[1.0.1]: https://github.com/dominicsayers/url_canonicalize/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/dominicsayers/url_canonicalize/compare/v0.2.1...v1.0.0
[0.2.1]: https://github.com/dominicsayers/url_canonicalize/compare/v0.2.0...v0.2.1
[0.2.0]: https://github.com/dominicsayers/url_canonicalize/compare/v0.1.15...v0.2.0
