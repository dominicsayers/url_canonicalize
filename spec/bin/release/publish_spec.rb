# frozen_string_literal: true

require 'open3'
require 'rbconfig'
require 'stringio'
require 'json'
require 'spec_helper'

module PublishSpecSupport
  EXECUTABLE = File.expand_path('../../../bin/release/publish', __dir__)
  VERSION = '1.2.3'
  TAG = 'v1.2.3'
  SHA = 'a' * 40
  OTHER_SHA = 'b' * 40
  PR_URL = 'https://github.com/dominicsayers/url_canonicalize/pull/123'
  VERSION_CONTENTS = <<~RUBY
    module URLCanonicalize
      VERSION = '1.2.3'
    end
  RUBY
  CHANGELOG_CONTENTS = <<~MARKDOWN
    ## [Unreleased]

    ## [1.2.3] - 2026-07-18

    - Release notes.

    [Unreleased]: https://github.com/dominicsayers/url_canonicalize/compare/v1.2.3...HEAD
    [1.2.3]: https://github.com/dominicsayers/url_canonicalize/compare/v1.2.2...v1.2.3
  MARKDOWN
  FETCH_COMMAND = %w[git fetch --no-tags origin main].freeze
  PR_COMMAND = %w[gh pr list --state merged --base main --head release-v1.2.3 --json
                  number,url,mergeCommit,mergedAt --limit 100].freeze
  ANCESTOR_COMMAND = ['git', 'merge-base', '--is-ancestor', SHA, 'origin/main'].freeze
  VERSION_COMMAND = ['git', 'show', "#{SHA}:lib/url_canonicalize/version.rb"].freeze
  CHANGELOG_COMMAND = ['git', 'show', "#{SHA}:CHANGELOG.md"].freeze
  LOCAL_REF_COMMAND = ['git', 'for-each-ref', '--format=%(refname)', "refs/tags/#{TAG}"].freeze
  LOCAL_SHA_COMMAND = ['git', 'rev-parse', '--verify', "refs/tags/#{TAG}^{commit}"].freeze
  REMOTE_TAG_COMMAND = ['git', 'ls-remote', '--tags', 'origin', "refs/tags/#{TAG}", "refs/tags/#{TAG}^{}"].freeze
  TAG_COMMAND = ['git', 'tag', TAG, SHA].freeze
  PUSH_COMMAND = ['git', 'push', 'origin', TAG].freeze
  RUN_LIST_COMMAND = ['gh', 'run', 'list', '--workflow', 'release.yml', '--commit', SHA, '--event', 'push', '--limit',
                      '100', '--json', 'databaseId,headBranch,headSha,event,createdAt'].freeze
  RUN_VIEW_COMMAND = %w[gh run view 321 --web].freeze
  RUN_WATCH_COMMAND = %w[gh run watch 321 --exit-status].freeze
  GEM_COMMAND = %w[gem list --remote --exact url_canonicalize --all].freeze
  SUCCESSFUL_RUNS = [FETCH_COMMAND, ANCESTOR_COMMAND, TAG_COMMAND, PUSH_COMMAND, RUN_VIEW_COMMAND,
                     RUN_WATCH_COMMAND].freeze

  class FakeRunner
    attr_reader :captures, :runs, :sleeps, :stdout, :stderr

    def initialize(input: '')
      @input = StringIO.new(input)
      @stdout = StringIO.new
      @stderr = StringIO.new
      @captures = []
      @runs = []
      @sleeps = []
      @capture_responses = Hash.new { |hash, key| hash[key] = [] }
      @run_responses = Hash.new { |hash, key| hash[key] = [] }
    end

    def queue_capture(command, *responses)
      @capture_responses[command].concat(responses)
      self
    end

    def queue_run(command, *responses)
      @run_responses[command].concat(responses.empty? ? [true] : responses)
      self
    end

    def replace_capture(command, *responses)
      @capture_responses[command] = responses
      self
    end

    def replace_run(command, *responses)
      @run_responses[command] = responses
      self
    end

    def capture(*command)
      captures << command
      consume(@capture_responses, command, 'capture')
    end

    def run(*command)
      runs << command
      consume(@run_responses, command, 'run')
    end

    def puts(message = '')
      stdout.puts(message)
    end

    def print(message)
      stdout.print(message)
    end

    def warn(message)
      stderr.puts(message)
    end

    def gets
      @input.gets
    end

    def sleep(duration)
      sleeps << duration
    end

    private

    def consume(responses, command, type)
      queue = responses[command]
      raise "Unexpected #{type} command: #{command.inspect}" if queue.empty?

      response = queue.shift
      raise response if response.is_a?(Exception)

      response
    end
  end

  def self.successful_runner(input: "publish #{TAG}\n", local_sha: nil, remote_output: '',
                             run_ids: [successful_run_json])
    runner = FakeRunner.new(input: input)
    queue_release_context(runner)
    queue_tags(runner, local_sha, remote_output)
    queue_workflow(runner, run_ids)
    runner
  end

  def self.queue_release_context(runner)
    runner.queue_run(FETCH_COMMAND)
    runner.queue_capture(PR_COMMAND, <<~JSON)
      [{"number":123,"url":"#{PR_URL}","mergeCommit":{"oid":"#{SHA}"},"mergedAt":"2026-07-18T10:00:00Z"}]
    JSON
    runner.queue_run(ANCESTOR_COMMAND)
    runner.queue_capture(VERSION_COMMAND, VERSION_CONTENTS)
    runner.queue_capture(CHANGELOG_COMMAND, CHANGELOG_CONTENTS)
  end

  def self.queue_tags(runner, local_sha, remote_output)
    runner.queue_capture(LOCAL_REF_COMMAND, local_sha ? "refs/tags/#{TAG}\n" : '')
    runner.queue_capture(LOCAL_SHA_COMMAND, "#{local_sha}\n") if local_sha
    runner.queue_capture(REMOTE_TAG_COMMAND, remote_output)
    return if remote_output.include?(SHA)

    runner.queue_run(TAG_COMMAND) unless local_sha
    runner.queue_run(PUSH_COMMAND)
  end

  def self.queue_workflow(runner, run_ids)
    runner.queue_capture(RUN_LIST_COMMAND, *run_ids)
    runner.queue_run(RUN_VIEW_COMMAND)
    runner.queue_run(RUN_WATCH_COMMAND)
    runner.queue_capture(GEM_COMMAND, "url_canonicalize (1.2.3)\n")
  end

  def self.successful_run_json
    workflow_runs_json(workflow_run(database_id: 321))
  end

  def self.duplicate_pull_requests_json
    first = { number: 123, url: PR_URL, mergeCommit: { oid: SHA }, mergedAt: '2026-07-18T10:00:00Z' }
    second = { number: 124, url: PR_URL, mergeCommit: { oid: OTHER_SHA }, mergedAt: '2026-07-18T11:00:00Z' }
    JSON.generate([first, second])
  end

  def self.mixed_workflow_runs_json
    workflow_runs_json(
      workflow_run(database_id: 111, branch: 'v1.2.2', created_at: '2026-07-18T13:00:00Z'),
      workflow_run(database_id: 222, event: 'workflow_dispatch', created_at: '2026-07-18T12:30:00Z'),
      workflow_run(database_id: 321)
    )
  end

  def self.multiple_matching_runs_json
    workflow_runs_json(
      workflow_run(database_id: 320, created_at: '2026-07-18T11:00:00Z'),
      workflow_run(database_id: 321)
    )
  end

  def self.wrong_workflow_runs_json
    workflow_runs_json(
      workflow_run(database_id: 111, branch: 'v1.2.2'),
      workflow_run(database_id: 222, event: 'workflow_dispatch')
    )
  end

  def self.workflow_runs_json(*runs)
    JSON.generate(runs)
  end

  def self.workflow_run(database_id:, branch: TAG, event: 'push', created_at: '2026-07-18T12:00:00Z')
    { databaseId: database_id, headBranch: branch, headSha: SHA, event: event, createdAt: created_at }
  end
end

load PublishSpecSupport::EXECUTABLE

# The required executable path mirrors bin/release rather than the class name.
# rubocop:disable RSpec/SpecFilePathFormat
RSpec.describe ReleaseTools::Publish do
  let(:runner) { PublishSpecSupport::FakeRunner.new }

  def publish(with_runner = PublishSpecSupport.successful_runner)
    described_class.run([PublishSpecSupport::VERSION], runner: with_runner)
  end

  def publish_error(with_runner)
    publish(with_runner)
  rescue ReleaseTools::Error => e
    e
  end

  def invalid_argument_observation
    arguments = [[], %w[1.2.3 extra], ['v1.2.3']]
    errors = arguments.map { |values| run_with_error(values) }
    [errors, runner.captures, runner.runs]
  end

  def run_with_error(arguments)
    described_class.run(arguments, runner: runner)
  rescue ReleaseTools::Error => e
    e.message
  end

  def publication_observation(publishing_runner, result)
    details = [PublishSpecSupport::PR_URL, PublishSpecSupport::SHA, PublishSpecSupport::TAG, 'protected environment']
    output_contains_details = details.all? { |detail| publishing_runner.stdout.string.include?(detail) }
    [result, publishing_runner.runs, output_contains_details]
  end

  def tag_mutations(run_log)
    run_log & [PublishSpecSupport::TAG_COMMAND, PublishSpecSupport::PUSH_COMMAND]
  end

  def timeout_observation(timeout_runner)
    error = publish_error(timeout_runner)
    [error.message, timeout_runner.captures.count(PublishSpecSupport::RUN_LIST_COMMAND), timeout_runner.sleeps,
     watch_activity(timeout_runner), gem_verified?(timeout_runner)]
  end

  def release_file_reads(with_runner)
    with_runner.captures & [PublishSpecSupport::VERSION_COMMAND, PublishSpecSupport::CHANGELOG_COMMAND]
  end

  def workflow_polled?(with_runner)
    with_runner.captures.include?(PublishSpecSupport::RUN_LIST_COMMAND)
  end

  def watch_activity(with_runner)
    with_runner.runs & [PublishSpecSupport::RUN_VIEW_COMMAND, PublishSpecSupport::RUN_WATCH_COMMAND]
  end

  def gem_verified?(with_runner)
    with_runner.captures.include?(PublishSpecSupport::GEM_COMMAND)
  end

  def git_activity_observation(with_runner)
    git_commands = (with_runner.runs + with_runner.captures).select { |command| command.first == 'git' }
    forbidden = git_commands.flatten & ['--force', '-f', '--delete', 'checkout', 'switch', 'pull']
    [forbidden, git_commands.select { |command| command[1] == 'push' }]
  end

  def browser_failure_observation(result, with_runner)
    stderr_details = ['could not open workflow', 'run 321', 'gh run view 321 --web']
    [result, with_runner.runs.include?(PublishSpecSupport::RUN_WATCH_COMMAND), gem_verified?(with_runner),
     stderr_details.all? { |detail| with_runner.stderr.string.include?(detail) }]
  end

  describe '.run' do
    it 'shows help successfully without inspecting or changing the repository' do
      result = described_class.run(['--help'], runner: runner)

      expect([result, runner.stdout.string, runner.captures, runner.runs])
        .to eq([true, described_class::HELP, [], []])
    end

    it 'fetches main without fetching or auto-following any tags' do
      publishing_runner = PublishSpecSupport.successful_runner

      publish(publishing_runner)

      fetches = publishing_runner.runs.select { |command| command.first(2) == %w[git fetch] }
      expect(fetches).to eq([%w[git fetch --no-tags origin main]])
    end

    it 'rejects missing, extra, and malformed versions before running commands' do
      format_error = "Version must use the X.Y.Z format\n#{described_class::USAGE}"

      expect(invalid_argument_observation)
        .to eq([[described_class::USAGE, described_class::USAGE, format_error], [], []])
    end

    it 'validates, confirms, tags, pushes, watches, and verifies a new release' do
      publishing_runner = PublishSpecSupport.successful_runner

      result = described_class.run([PublishSpecSupport::VERSION], runner: publishing_runner)

      expect(publication_observation(publishing_runner, result))
        .to eq([true, PublishSpecSupport::SUCCESSFUL_RUNS, true])
    end
  end

  describe 'merged release validation' do
    it 'fails clearly when the fetch executable is unavailable' do
      missing_executable = ReleaseTools::Error.new("Command could not be executed: git fetch\nExecutable was not found")
      unavailable_runner = PublishSpecSupport::FakeRunner.new.queue_run(PublishSpecSupport::FETCH_COMMAND, missing_executable)

      expect(publish_error(unavailable_runner).message).to include('Command could not be executed', 'git fetch')
    end

    it 'requires exactly one merged release pull request' do
      runners = ['[]', PublishSpecSupport.duplicate_pull_requests_json].map do |json|
        PublishSpecSupport.successful_runner.replace_capture(PublishSpecSupport::PR_COMMAND, json)
      end

      expect(runners.map { |configured_runner| publish_error(configured_runner).message })
        .to all(match(/exactly one.*pull request/i))
    end

    it 'rejects malformed pull request JSON' do
      malformed_runner = PublishSpecSupport.successful_runner
                                           .replace_capture(PublishSpecSupport::PR_COMMAND, '{not json')

      expect(publish_error(malformed_runner).message).to include('Malformed merged pull request JSON')
    end

    it 'requires a usable merge commit SHA and pull request metadata' do
      missing_sha = '[{"number":123,"url":"https://example.test/pr/123","mergeCommit":null,"mergedAt":"now"}]'
      malformed_runner = PublishSpecSupport.successful_runner
                                           .replace_capture(PublishSpecSupport::PR_COMMAND, missing_sha)

      expect(publish_error(malformed_runner).message).to match(/missing.*merge commit SHA/i)
    end

    it 'reports wrongly typed pull request fields as a release error' do
      wrong_type = '[{"number":123,"url":"https://example.test/pr/123","mergeCommit":"sha","mergedAt":"now"}]'
      malformed_runner = PublishSpecSupport.successful_runner
                                           .replace_capture(PublishSpecSupport::PR_COMMAND, wrong_type)

      expect { publish(malformed_runner) }.to raise_error(ReleaseTools::Error, /missing.*merge commit SHA/i)
    end

    it 'requires the merge commit to be an ancestor of origin/main before reading it' do
      command_failure = ReleaseTools::Error.new('Command failed: git merge-base --is-ancestor ...')
      ancestry_runner = PublishSpecSupport.successful_runner
                                          .replace_run(PublishSpecSupport::ANCESTOR_COMMAND, command_failure)

      clear_message = "Merge commit #{PublishSpecSupport::SHA} is not an ancestor of origin/main"
      expect([publish_error(ancestry_runner).message, release_file_reads(ancestry_runner)]).to eq([clear_message, []])
    end

    it 'requires the exact requested version assignment at the merge commit' do
      wrong_version = PublishSpecSupport::VERSION_CONTENTS.sub("VERSION = '1.2.3'", "VERSION = '1.2.4'")
      version_runner = PublishSpecSupport.successful_runner
                                         .replace_capture(PublishSpecSupport::VERSION_COMMAND, wrong_version)

      expect(publish_error(version_runner).message).to include("does not assign VERSION = '1.2.3' exactly")
    end

    it 'requires an exact dated changelog heading' do
      wrong_heading = PublishSpecSupport::CHANGELOG_CONTENTS.sub('2026-07-18', '18 July 2026')
      changelog_runner = PublishSpecSupport.successful_runner
                                           .replace_capture(PublishSpecSupport::CHANGELOG_COMMAND, wrong_heading)

      expect(publish_error(changelog_runner).message).to include('lacks the exact 1.2.3 heading')
    end

    it 'requires the release comparison link to end at the requested tag' do
      wrong_link = PublishSpecSupport::CHANGELOG_CONTENTS.sub('v1.2.2...v1.2.3', 'v1.2.2...v1.2.4')
      changelog_runner = PublishSpecSupport.successful_runner
                                           .replace_capture(PublishSpecSupport::CHANGELOG_COMMAND, wrong_link)

      expect(publish_error(changelog_runner).message).to include('comparison link')
    end
  end

  describe 'existing tags and confirmation' do
    it 'retries only the push when a matching local tag already exists' do
      retry_runner = PublishSpecSupport.successful_runner(local_sha: PublishSpecSupport::SHA)

      publish(retry_runner)

      expected = [PublishSpecSupport::PUSH_COMMAND, "Local tag: exists at #{PublishSpecSupport::SHA}"]
      expect([tag_mutations(retry_runner.runs), retry_runner.stdout.string])
        .to match([[PublishSpecSupport::PUSH_COMMAND], include(expected.last)])
    end

    it 'skips tag mutation when a matching lightweight remote tag exists' do
      remote = "#{PublishSpecSupport::SHA}\trefs/tags/#{PublishSpecSupport::TAG}\n"
      retry_runner = PublishSpecSupport.successful_runner(remote_output: remote)

      publish(retry_runner)

      expect([tag_mutations(retry_runner.runs), retry_runner.stdout.string])
        .to match([[], include("Remote tag: exists at #{PublishSpecSupport::SHA}")])
    end

    it 'uses the peeled commit for a matching annotated remote tag' do
      remote = <<~TAGS
        #{PublishSpecSupport::OTHER_SHA}\trefs/tags/#{PublishSpecSupport::TAG}
        #{PublishSpecSupport::SHA}\trefs/tags/#{PublishSpecSupport::TAG}^{}
      TAGS
      retry_runner = PublishSpecSupport.successful_runner(remote_output: remote)

      expect([publish(retry_runner), tag_mutations(retry_runner.runs)]).to eq([true, []])
    end

    it 'rejects a conflicting local tag without mutating any tag' do
      conflict_runner = PublishSpecSupport.successful_runner(local_sha: PublishSpecSupport::OTHER_SHA)

      error = publish_error(conflict_runner)
      expect([error.message, tag_mutations(conflict_runner.runs)])
        .to match([include('Local tag', PublishSpecSupport::OTHER_SHA), []])
    end

    it 'rejects a conflicting remote tag without mutating any tag' do
      remote = "#{PublishSpecSupport::OTHER_SHA}\trefs/tags/#{PublishSpecSupport::TAG}\n"
      conflict_runner = PublishSpecSupport.successful_runner(remote_output: remote)

      error = publish_error(conflict_runner)
      expect([error.message, tag_mutations(conflict_runner.runs)])
        .to match([include('Remote tag', PublishSpecSupport::OTHER_SHA), []])
    end

    it 'rejects malformed or ambiguous remote tag output' do
      ambiguous = <<~TAGS
        #{PublishSpecSupport::SHA}\trefs/tags/#{PublishSpecSupport::TAG}
        #{PublishSpecSupport::OTHER_SHA}\trefs/tags/#{PublishSpecSupport::TAG}
      TAGS
      malformed_runner = PublishSpecSupport.successful_runner(remote_output: ambiguous)

      expect(publish_error(malformed_runner).message).to include('Unexpected remote tag data')
    end

    it 'requires the exact confirmation before creating or pushing a tag' do
      confirmation_runner = PublishSpecSupport.successful_runner(input: "publish v1.2.3 \n")

      error = publish_error(confirmation_runner)
      expect([error.message, tag_mutations(confirmation_runner.runs), workflow_polled?(confirmation_runner)])
        .to match([/cancelled/i, [], false])
    end

    it 'treats end-of-input as cancellation even when the remote tag exists' do
      remote = "#{PublishSpecSupport::SHA}\trefs/tags/#{PublishSpecSupport::TAG}\n"
      confirmation_runner = PublishSpecSupport.successful_runner(input: '', remote_output: remote)

      expect([publish_error(confirmation_runner).message, workflow_polled?(confirmation_runner)])
        .to match([/cancelled/i, false])
    end
  end

  describe 'tag publication boundary' do
    it 'stops before pushing when local tag creation fails' do
      failing_runner = PublishSpecSupport.successful_runner
                                         .replace_run(PublishSpecSupport::TAG_COMMAND, ReleaseTools::Error.new('tag creation failed'))

      expect([publish_error(failing_runner).message, tag_mutations(failing_runner.runs), workflow_polled?(failing_runner)])
        .to eq(['tag creation failed', [PublishSpecSupport::TAG_COMMAND], false])
    end

    it 'leaves a newly created local tag available when pushing fails' do
      failing_runner = PublishSpecSupport.successful_runner
                                         .replace_run(PublishSpecSupport::PUSH_COMMAND, ReleaseTools::Error.new('tag push failed'))

      expect([publish_error(failing_runner).message, tag_mutations(failing_runner.runs), workflow_polled?(failing_runner)])
        .to eq(['tag push failed', [PublishSpecSupport::TAG_COMMAND, PublishSpecSupport::PUSH_COMMAND], false])
    end

    it 'never forces, deletes, checks out, pulls, or pushes main' do
      publishing_runner = PublishSpecSupport.successful_runner

      publish(publishing_runner)

      expect(git_activity_observation(publishing_runner)).to eq([[], [PublishSpecSupport::PUSH_COMMAND]])
    end
  end

  describe 'release workflow monitoring' do
    it 'polls with five-second waits until a delayed workflow appears' do
      delayed_runner = PublishSpecSupport.successful_runner(run_ids: ['[]', '[]', PublishSpecSupport.successful_run_json])

      publish(delayed_runner)

      expect([delayed_runner.captures.count(PublishSpecSupport::RUN_LIST_COMMAND), delayed_runner.sleeps])
        .to eq([3, [5, 5]])
    end

    it 'fails after twelve attempts and sixty seconds without viewing or watching' do
      timeout_runner = PublishSpecSupport.successful_runner(run_ids: Array.new(12, '[]'))

      timeout_message = "Release workflow did not appear for #{PublishSpecSupport::SHA} after 60 seconds"
      expect(timeout_observation(timeout_runner)).to eq([timeout_message, 12, Array.new(12, 5), [], false])
    end

    it 'rejects malformed workflow JSON without opening or watching anything' do
      malformed_runner = PublishSpecSupport.successful_runner(run_ids: ['not-json'])

      expect([publish_error(malformed_runner).message, watch_activity(malformed_runner)])
        .to match([include('Malformed release workflow run JSON'), []])
    end

    it 'requires a usable workflow database ID' do
      malformed = PublishSpecSupport.successful_run_json.sub('"databaseId":321', '"databaseId":null')
      malformed_runner = PublishSpecSupport.successful_runner(run_ids: [malformed])

      expect(publish_error(malformed_runner).message).to include('missing a databaseId')
    end

    it 'continues watching and verifying when opening the run in a browser fails' do
      failing_runner = PublishSpecSupport.successful_runner
                                         .replace_run(PublishSpecSupport::RUN_VIEW_COMMAND, ReleaseTools::Error.new('could not open workflow'))

      expect(browser_failure_observation(publish(failing_runner), failing_runner)).to eq([true, true, true, true])
    end

    it 'selects only the requested tag push run from other runs for the same commit' do
      mixed_runner = PublishSpecSupport.successful_runner(run_ids: [PublishSpecSupport.mixed_workflow_runs_json])

      publish(mixed_runner)

      expect(mixed_runner.runs).to include(PublishSpecSupport::RUN_VIEW_COMMAND, PublishSpecSupport::RUN_WATCH_COMMAND)
    end

    it 'chooses the latest requested-tag push when more than one matches' do
      retry_runner = PublishSpecSupport.successful_runner(run_ids: [PublishSpecSupport.multiple_matching_runs_json])

      publish(retry_runner)

      expect(retry_runner.runs).to include(PublishSpecSupport::RUN_VIEW_COMMAND, PublishSpecSupport::RUN_WATCH_COMMAND)
    end

    it 'keeps polling when only wrong-tag or non-push runs are returned' do
      run_ids = [PublishSpecSupport.wrong_workflow_runs_json, PublishSpecSupport.successful_run_json]
      polling_runner = PublishSpecSupport.successful_runner(run_ids: run_ids)

      publish(polling_runner)

      expect([polling_runner.captures.count(PublishSpecSupport::RUN_LIST_COMMAND), polling_runner.sleeps])
        .to eq([2, [5]])
    end

    it 'stops before gem verification if watching the run fails' do
      failing_runner = PublishSpecSupport.successful_runner
                                         .replace_run(PublishSpecSupport::RUN_WATCH_COMMAND, ReleaseTools::Error.new('release workflow failed'))

      expect([publish_error(failing_runner).message, gem_verified?(failing_runner)])
        .to eq(['release workflow failed', false])
    end

    it 'fails when RubyGems does not list the requested version' do
      missing_gem_runner = PublishSpecSupport.successful_runner
                                             .replace_capture(PublishSpecSupport::GEM_COMMAND, "url_canonicalize (1.2.2)\n")

      expect(publish_error(missing_gem_runner).message).to include('does not list', PublishSpecSupport::VERSION)
    end
  end

  describe 'executable entry point' do
    it 'has executable permission' do
      expect(File.executable?(PublishSpecSupport::EXECUTABLE)).to be(true)
    end

    it 'prints help successfully without errors' do
      stdout, stderr, status = run_executable('--help')

      expect([status.success?, stdout, stderr]).to eq([true, described_class::HELP, ''])
    end

    it 'reports usage errors concisely with a non-zero exit status' do
      stdout, stderr, status = run_executable

      expect([status.success?, stdout, stderr])
        .to match([false, '', %r{Error:.*Usage: bin/release/publish VERSION}m])
    end

    # An unbundled environment keeps Bundler's RUBYOPT out of the child
    # process, whose stderr must contain only the executable's own output.
    def run_executable(*arguments)
      Bundler.with_unbundled_env { Open3.capture3(RbConfig.ruby, PublishSpecSupport::EXECUTABLE, *arguments) }
    end
  end
end
# rubocop:enable RSpec/SpecFilePathFormat
