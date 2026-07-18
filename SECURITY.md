# Security Policy

## Supported versions

| Version | Supported          |
| ------- | ------------------ |
| 1.x     | :white_check_mark: |
| < 1.0   | :x:                |

## Reporting a vulnerability

Please do not open a public issue for security problems. Instead, use GitHub's
private vulnerability reporting: go to the repository's **Security** tab and
choose **Report a vulnerability**, or visit
<https://github.com/dominicsayers/url_canonicalize/security/advisories/new>.

You should receive a response within a week. Please include a proof of concept
or reproduction steps where possible.

## Scope notes

URLCanonicalize fetches caller-supplied URLs, so requests forged through
redirects or canonical links (SSRF), TLS verification, resource exhaustion and
destination policy bypasses are all in scope. The README's "Security and
limits" section describes the protections the gem provides by default.
