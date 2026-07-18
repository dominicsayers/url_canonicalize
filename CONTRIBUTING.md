# Contributing

## Development setup

The Ruby version is managed with [mise](https://mise.jdx.dev/):

```sh
mise install
bundle install
```

## Running the checks

```sh
bundle exec rspec    # tests; CI enforces 100% line and branch coverage
bundle exec rubocop  # static code analysis
```

Please write tests first (the suite is TDD-driven), keep coverage at 100% and
add a CHANGELOG entry under **Unreleased** for user-visible changes.

## Releasing

Releases are published to RubyGems by the tag-triggered
[release workflow](.github/workflows/release.yml) using RubyGems
[Trusted Publishing](https://guides.rubygems.org/trusted-publishing/) — no API
key is stored anywhere.

1. Update `lib/url_canonicalize/version.rb`.
2. Move the **Unreleased** notes in `CHANGELOG.md` under the new version
   heading with today's date, and update the compare links.
3. Commit, then tag the release commit and push it:

   ```sh
   git tag v1.2.3
   git push origin main v1.2.3
   ```

The workflow verifies the gem's contents, installs it into a clean
environment, checks the tag matches the gem version, and then publishes from
the protected `release` environment.
