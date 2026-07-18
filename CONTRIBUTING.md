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

### One-time setup

1. Configure a Trusted Publisher for the `url_canonicalize` gem on RubyGems:

   - Repository owner: `dominicsayers`
   - Repository: `url_canonicalize`
   - Workflow: `release.yml`
   - Environment: `release`

2. Create the `release` environment in the GitHub repository settings. It may
   have required reviewers; if so, an authorised reviewer must approve each
   release workflow deployment before publication.

### Release checklist

`main` is protected, so prepare the release on a short-lived branch and merge
it through a pull request. In the examples below, `1.2.3` is hypothetical;
replace it with the version you are actually releasing.

1. Start from the latest `main`, create the required release branch, and prepare
   the release:

   ```sh
   release_version=1.2.3

   git switch main
   git pull --ff-only origin main
   git switch -c "release-v${release_version}"
   mise exec -- bin/release/prepare "$release_version"
   ```

   `prepare` requires exactly that release branch and a clean working tree. It
   updates `lib/url_canonicalize/version.rb`, `Gemfile.lock`, and `CHANGELOG.md`,
   then runs RSpec, RuboCop, and a gem build. It never commits, pushes, or opens
   a pull request.

   If a verification command fails, the prepared files remain available to
   inspect and fix before rerunning the command. If installing the prepared
   version and changelog files fails in a handled way, their originals are
   restored. To rerun `prepare` itself, first revert the prepared files
   (for example with `git restore .`) — it requires a clean working tree.

2. Review the prepared files, then commit them, push the release branch, and
   open a pull request targeting `main`:

   ```sh
   release_version=1.2.3

   git diff --check
   git diff -- lib/url_canonicalize/version.rb Gemfile.lock CHANGELOG.md
   git add lib/url_canonicalize/version.rb Gemfile.lock CHANGELOG.md
   git commit -m "chore: release version ${release_version}"
   git push -u origin "release-v${release_version}"
   gh pr create --base main --head "release-v${release_version}" --fill
   ```

   Merge the pull request only after its checks, including **Verify gem**, pass.
   Do not push directly to protected `main`.

3. After the pull request is merged, publish the version. Set the version again
   because this is normally a separate shell session:

   ```sh
   release_version=1.2.3
   mise exec -- bin/release/publish "$release_version"
   ```

   `publish` fetches `origin/main` without modifying local `main` or fetching
   tags. It finds exactly one merged `release-vVERSION` pull request, validates
   its merge commit, version, changelog, and local and remote tag state, then
   shows the release details. Conflicting tags stop publication; matching tag
   state makes retries safe.

   Publication continues only after the exact confirmation shown in the prompt.
   It creates and pushes only the version tag, locates the exact tag-triggered
   workflow run, tries to open it in a browser, watches it to completion, and
   verifies the version on RubyGems. If the browser cannot be opened, follow the
   printed URL. If the workflow is waiting, ask an authorised reviewer to
   select **Review deployments**, select `release`, and choose **Approve and
   deploy**.

Run `mise exec -- bin/release/prepare --help` or
`mise exec -- bin/release/publish --help` for a command summary.
