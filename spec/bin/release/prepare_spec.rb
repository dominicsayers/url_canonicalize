# frozen_string_literal: true

require 'bundler'
require 'date'
require 'fileutils'
require 'open3'
require 'rbconfig'
require 'stringio'
require 'spec_helper'
require 'tmpdir'

module PrepareSpecSupport
  EXECUTABLE = File.expand_path('../../../bin/release/prepare', __dir__)
  TODAY = Date.new(2026, 7, 18)
  CURRENT_VERSION_CONTENTS = <<~RUBY
    # frozen_string_literal: true

    module URLCanonicalize
      VERSION = '1.2.2'
    end
  RUBY
  UNRELEASED_NOTES = <<~MARKDOWN
    ### Fixed

    - Correct canonical URL handling.

  MARKDOWN
  CHANGELOG_CONTENTS = <<~MARKDOWN.freeze
    # Changelog

    ## [Unreleased]

    #{UNRELEASED_NOTES}## [1.2.2] - 2026-06-01

    - Previous release.

    [Unreleased]: https://github.com/dominicsayers/url_canonicalize/compare/v1.2.2...HEAD
    [1.2.2]: https://github.com/dominicsayers/url_canonicalize/compare/v1.2.1...v1.2.2
  MARKDOWN
  VERIFICATION_COMMANDS = [
    %w[mise exec -- bundle install],
    %w[mise exec -- bundle exec rspec],
    %w[mise exec -- bundle exec rubocop],
    %w[mise exec -- bundle exec rake build]
  ].freeze

  class FakeRunner
    attr_reader :captures, :runs, :stdout

    def initialize(branch: 'release-v1.2.3', status: '', fail_on: nil)
      @branch = branch
      @status = status
      @fail_on = fail_on
      @captures = []
      @runs = []
      @stdout = StringIO.new
    end

    def capture(*command)
      captures << command
      return "#{@branch}\n" if command == %w[git symbolic-ref --quiet --short HEAD]
      return @status if command == %w[git status --porcelain=v1]

      raise "Unexpected capture command: #{command.inspect}"
    end

    def run(*command)
      runs << command
      raise ReleaseTools::Error, 'simulated command failure' if command == @fail_on

      nil
    end

    def puts(message = '')
      stdout.puts(message)
    end
  end

  class RenameSequence
    attr_reader :calls

    def initialize(*failure_calls)
      @failure_calls = failure_calls
      @calls = 0
    end

    def call(source, target)
      @calls += 1
      raise Errno::EIO, 'simulated rename failure' if @failure_calls.include?(calls)

      File.rename(source, target)
    end
  end
end

load PrepareSpecSupport::EXECUTABLE

# The required executable path mirrors bin/release rather than the class name.
# rubocop:disable RSpec/SpecFilePathFormat
RSpec.describe ReleaseTools::Prepare do
  let(:root) { Dir.mktmpdir('release-prepare-spec') }
  let(:runner) { PrepareSpecSupport::FakeRunner.new }

  before do
    FileUtils.mkdir_p(File.dirname(version_path))
    File.write(version_path, PrepareSpecSupport::CURRENT_VERSION_CONTENTS)
    File.write(changelog_path, PrepareSpecSupport::CHANGELOG_CONTENTS)
  end

  after do
    FileUtils.remove_entry(root)
  end

  def prepare(version = '1.2.3', with_runner: runner, with_writer: nil)
    options = { runner: with_runner, root: root, today: PrepareSpecSupport::TODAY }
    options[:writer] = with_writer if with_writer
    described_class.run([version], **options)
  end

  def version_path
    File.join(root, 'lib/url_canonicalize/version.rb')
  end

  def changelog_path
    File.join(root, 'CHANGELOG.md')
  end

  def release_error(version = '1.2.3', with_runner: runner, with_writer: nil)
    prepare(version, with_runner: with_runner, with_writer: with_writer)
  rescue ReleaseTools::Error => e
    e
  end

  def run_with_arguments(arguments, at_root: root)
    described_class.run(arguments, runner: runner, root: at_root, today: PrepareSpecSupport::TODAY)
  end

  def ignore_release_error
    yield
  rescue ReleaseTools::Error
    nil
  end

  describe '.run' do
    it 'shows help successfully without inspecting or changing the repository' do
      missing_root = File.join(root, 'does-not-exist')
      result = run_with_arguments(['--help'], at_root: missing_root)

      expect([result, runner.stdout.string, runner.captures, runner.runs])
        .to eq([true, described_class::HELP, [], []])
    end

    it 'rejects a missing version with usage guidance' do
      expect { run_with_arguments([]) }
        .to raise_error(ReleaseTools::Error, %r{Usage: bin/release/prepare VERSION})
    end

    it 'rejects extra arguments with usage guidance' do
      expect { run_with_arguments(%w[1.2.3 extra]) }
        .to raise_error(ReleaseTools::Error, %r{Usage: bin/release/prepare VERSION})
    end

    it 'rejects a malformed version with format and usage guidance' do
      expect { run_with_arguments(['v1.2.3']) }
        .to raise_error(ReleaseTools::Error, %r{X\.Y\.Z.*Usage: bin/release/prepare VERSION}m)
    end

    it 'rejects invalid arguments before inspecting the repository' do
      invalid_arguments = [[], %w[1.2.3 extra], ['v1.2.3']]
      invalid_arguments.each { |arguments| ignore_release_error { run_with_arguments(arguments) } }

      expect([runner.captures, runner.runs]).to eq([[], []])
    end
  end

  describe 'preparation guards' do
    it 'requires the exact release branch before reading repository state' do
      wrong_branch_runner = PrepareSpecSupport::FakeRunner.new(branch: 'main')
      error = release_error(with_runner: wrong_branch_runner)

      expect([error.message, wrong_branch_runner.captures, wrong_branch_runner.runs])
        .to eq(['Current branch must be release-v1.2.3, not main', [%w[git symbolic-ref --quiet --short HEAD]], []])
    end

    it 'rejects tracked changes using porcelain status' do
      dirty_runner = PrepareSpecSupport::FakeRunner.new(status: " M README.md\n")
      error = release_error(with_runner: dirty_runner)

      expect([error.message, dirty_runner.captures, dirty_runner.runs]).to eq(dirty_tree_failure)
    end

    it 'rejects a nonignored untracked file before changing release files' do
      untracked_runner = PrepareSpecSupport::FakeRunner.new(status: "?? scratch.txt\n")
      error = release_error(with_runner: untracked_runner)

      expect([error.message, untracked_runner.captures, File.binread(version_path), File.binread(changelog_path)])
        .to eq(untracked_tree_failure)
    end

    it 'reports a missing repository root as a release error' do
      missing_root = File.join(root, 'does-not-exist')

      expect { run_with_arguments(['1.2.3'], at_root: missing_root) }
        .to raise_error(ReleaseTools::Error, /does-not-exist/)
    end

    it 'rejects a current VERSION outside the X.Y.Z format' do
      File.write(version_path, PrepareSpecSupport::CURRENT_VERSION_CONTENTS.sub("'1.2.2'", "'1.2'"))

      expect { prepare }.to raise_error(ReleaseTools::Error, /Current VERSION must use the X\.Y\.Z format/)
    end

    it 'rejects a requested version equal to the current version' do
      equal_runner = PrepareSpecSupport::FakeRunner.new(branch: 'release-v1.2.2')

      expect(release_error('1.2.2', with_runner: equal_runner).message).to eq('Version 1.2.2 must be greater than 1.2.2')
    end

    it 'rejects a requested version below the current version' do
      lower_runner = PrepareSpecSupport::FakeRunner.new(branch: 'release-v1.2.1')

      expect(release_error('1.2.1', with_runner: lower_runner).message).to eq('Version 1.2.1 must be greater than 1.2.2')
    end

    it 'rejects duplicate VERSION assignments' do
      duplicate = PrepareSpecSupport::CURRENT_VERSION_CONTENTS.sub("end\n", "  VERSION = '1.2.1'\nend\n")
      File.write(version_path, duplicate)

      expect { prepare }.to raise_error(ReleaseTools::Error, /exactly one VERSION assignment/)
    end

    it 'rejects a malformed VERSION assignment' do
      malformed = PrepareSpecSupport::CURRENT_VERSION_CONTENTS.sub("VERSION = '1.2.2'", 'VERSION = current_version')
      File.write(version_path, malformed)

      expect { prepare }.to raise_error(ReleaseTools::Error, /exactly one VERSION assignment/)
    end

    it 'atomically rejects an additional assignment-looking VERSION line' do
      duplicate = PrepareSpecSupport::CURRENT_VERSION_CONTENTS.sub("end\n", "  VERSION = \"1.2.1\"\nend\n")
      File.write(version_path, duplicate)
      error = release_error

      expect([error.message, File.binread(version_path), File.binread(changelog_path)])
        .to eq(['lib/url_canonicalize/version.rb must contain exactly one VERSION assignment', duplicate, PrepareSpecSupport::CHANGELOG_CONTENTS])
    end

    it 'requires exactly one Unreleased heading' do
      duplicate = PrepareSpecSupport::CHANGELOG_CONTENTS.sub('# Changelog', "# Changelog\n\n## [Unreleased]")
      File.write(changelog_path, duplicate)

      expect { prepare }.to raise_error(ReleaseTools::Error, /exactly one Unreleased heading/)
    end

    it 'requires an Unreleased comparison link even when nothing follows the notes' do
      no_boundary = "# Changelog\n\n## [Unreleased]\n\n#{PrepareSpecSupport::UNRELEASED_NOTES}"
      File.write(changelog_path, no_boundary)

      expect { prepare }.to raise_error(ReleaseTools::Error, /exactly one Unreleased comparison link/)
    end

    it 'rejects duplicate Unreleased comparison links' do
      duplicate_link = "[Unreleased]: https://example.test/compare/v1.2.2...HEAD\n"
      File.write(changelog_path, PrepareSpecSupport::CHANGELOG_CONTENTS + duplicate_link)

      expect { prepare }.to raise_error(ReleaseTools::Error, /exactly one Unreleased comparison link/)
    end

    it 'rejects a malformed Unreleased comparison link' do
      malformed = PrepareSpecSupport::CHANGELOG_CONTENTS.sub('compare/v1.2.2...HEAD', 'compare/1.2.2..HEAD')
      File.write(changelog_path, malformed)

      expect { prepare }.to raise_error(ReleaseTools::Error, /exactly one Unreleased comparison link/)
    end

    it 'requires non-empty Unreleased notes' do
      empty = PrepareSpecSupport::CHANGELOG_CONTENTS.sub(PrepareSpecSupport::UNRELEASED_NOTES, '')
      File.write(changelog_path, empty)

      expect { prepare }.to raise_error(ReleaseTools::Error, /Unreleased section has no notes/)
    end

    it 'atomically rejects an empty Unreleased section followed only by reference links' do
      malformed = changelog_without_release_heading
      File.write(changelog_path, malformed)
      error = release_error

      expect([error.message, File.binread(version_path), File.binread(changelog_path)])
        .to eq(['CHANGELOG.md Unreleased section has no notes', PrepareSpecSupport::CURRENT_VERSION_CONTENTS, malformed])
    end

    it 'rejects an existing heading for the requested version' do
      File.write(changelog_path, changelog_with_existing_heading)

      expect { prepare }.to raise_error(ReleaseTools::Error, /heading for 1\.2\.3 already exists/)
    end

    it 'rejects a malformed existing heading for the requested version' do
      malformed = PrepareSpecSupport::CHANGELOG_CONTENTS.sub('## [1.2.2]', '## [1.2.3] unexpected text')
      File.write(changelog_path, malformed)

      expect { prepare }.to raise_error(ReleaseTools::Error, /heading for 1\.2\.3 already exists/)
    end

    it 'rejects an existing comparison link for the requested version' do
      existing_link = <<~MARKDOWN
        #{PrepareSpecSupport::CHANGELOG_CONTENTS}[1.2.3]: https://github.com/dominicsayers/url_canonicalize/compare/v1.2.2...v1.2.3
      MARKDOWN
      File.write(changelog_path, existing_link)

      expect { prepare }.to raise_error(ReleaseTools::Error, /comparison link for 1\.2\.3 already exists/)
    end

    it 'rejects an Unreleased comparison whose previous version does not match VERSION' do
      mismatched = PrepareSpecSupport::CHANGELOG_CONTENTS.sub('compare/v1.2.2...HEAD', 'compare/v1.2.1...HEAD')
      File.write(changelog_path, mismatched)

      expect { prepare }.to raise_error(ReleaseTools::Error, /compares from v1\.2\.1, but VERSION is 1\.2\.2/)
    end

    it 'computes both transformations before writing either file' do
      malformed = PrepareSpecSupport::CHANGELOG_CONTENTS.sub('## [Unreleased]', '## Unreleased')
      File.write(changelog_path, malformed)
      release_error

      expect([File.binread(version_path), File.binread(changelog_path)])
        .to eq([PrepareSpecSupport::CURRENT_VERSION_CONTENTS, malformed])
    end
  end

  describe 'successful preparation' do
    def expected_version_contents
      PrepareSpecSupport::CURRENT_VERSION_CONTENTS.sub("VERSION = '1.2.2'", "VERSION = '1.2.3'")
    end

    def expected_changelog_contents
      <<~MARKDOWN
        # Changelog

        ## [Unreleased]

        ## [1.2.3] - 2026-07-18

        #{PrepareSpecSupport::UNRELEASED_NOTES}## [1.2.2] - 2026-06-01

        - Previous release.

        [Unreleased]: https://github.com/dominicsayers/url_canonicalize/compare/v1.2.3...HEAD
        [1.2.3]: https://github.com/dominicsayers/url_canonicalize/compare/v1.2.2...v1.2.3
        [1.2.2]: https://github.com/dominicsayers/url_canonicalize/compare/v1.2.1...v1.2.2
      MARKDOWN
    end

    it 'includes Rake in the bundle used by release verification' do
      expect(Bundler.load.specs.map(&:name)).to include('rake')
    end

    it 'updates the VERSION assignment exactly' do
      prepare

      expect(File.binread(version_path)).to eq(expected_version_contents)
    end

    it 'moves the Unreleased notes beneath the exact dated heading and links' do
      prepare

      expect(File.binread(changelog_path)).to eq(expected_changelog_contents)
    end

    it 'runs every verification command in order' do
      prepare

      expect(runner.runs).to eq(PrepareSpecSupport::VERIFICATION_COMMANDS)
    end

    it 'stops running checks after the first command failure' do
      failing_runner = PrepareSpecSupport::FakeRunner.new(fail_on: PrepareSpecSupport::VERIFICATION_COMMANDS.fetch(1))
      error = release_error(with_runner: failing_runner)

      expect([error.message, failing_runner.runs])
        .to eq(['simulated command failure', PrepareSpecSupport::VERIFICATION_COMMANDS.first(2)])
    end

    it 'leaves both transformed files available when a later check fails' do
      failing_runner = PrepareSpecSupport::FakeRunner.new(fail_on: PrepareSpecSupport::VERIFICATION_COMMANDS.fetch(2))
      error = release_error(with_runner: failing_runner)

      expect([error.message, File.binread(version_path), File.binread(changelog_path), failing_runner.runs])
        .to eq(['simulated command failure', expected_version_contents, expected_changelog_contents, PrepareSpecSupport::VERIFICATION_COMMANDS.first(3)])
    end

    it 'preserves both release file modes' do
      File.chmod(0o600, version_path)
      File.chmod(0o640, changelog_path)
      prepare

      expect([File.stat(version_path).mode & 0o7777, File.stat(changelog_path).mode & 0o7777]).to eq([0o600, 0o640])
    end

    it 'only invokes read-only Git commands' do
      prepare
      git_actions = (runner.captures + runner.runs).filter_map { |command| command[1] if command.first == 'git' }

      expect(git_actions & %w[add commit push tag switch checkout]).to be_empty
    end

    it 'tells the maintainer how to finish the pull request step' do
      prepare

      expect(runner.stdout.string).to include('Inspect the changes', 'commit', 'push', 'merge the pull request')
    end
  end

  describe 'transactional file installation' do
    it 'reports staging failures without changing either release file' do
      error = with_read_only(File.dirname(version_path)) { release_error }

      expect([error.message, File.binread(version_path), File.binread(changelog_path)])
        .to match([/Could not stage release files/, PrepareSpecSupport::CURRENT_VERSION_CONTENTS,
                   PrepareSpecSupport::CHANGELOG_CONTENTS])
    end

    it 'tolerates temporary file cleanup failures after a failed installation' do
      allow(FileUtils).to receive(:rm_f).and_raise(Errno::EACCES.new('temporary file'))
      writer = described_class::TransactionalWriter.new(renamer: PrepareSpecSupport::RenameSequence.new(2))

      expect(release_error(with_writer: writer).message).to include('original release files were restored')
    end

    it 'restores both originals and removes temporary files when the second installation fails' do
      renamer = PrepareSpecSupport::RenameSequence.new(2)
      writer = described_class::TransactionalWriter.new(renamer: renamer)
      error = release_error(with_writer: writer)

      expect([error.message, File.binread(version_path), File.binread(changelog_path), release_temp_files])
        .to match([/original release files were restored/, PrepareSpecSupport::CURRENT_VERSION_CONTENTS, PrepareSpecSupport::CHANGELOG_CONTENTS, []])
    end

    it 'warns that files may be inconsistent if restoring an original fails' do
      renamer = PrepareSpecSupport::RenameSequence.new(2, 3)
      writer = described_class::TransactionalWriter.new(renamer: renamer)
      error = release_error(with_writer: writer)

      expect([error.message, release_temp_files])
        .to match([/rollback failed.*release files may be inconsistent/i, []])
    end
  end

  describe 'executable entry point' do
    it 'has executable permission' do
      expect(File.executable?(PrepareSpecSupport::EXECUTABLE)).to be(true)
    end

    it 'prints help successfully without errors' do
      stdout, stderr, status = run_executable('--help')

      expect([status.success?, stdout, stderr]).to eq([true, described_class::HELP, ''])
    end

    it 'reports usage errors concisely with a non-zero exit status' do
      stdout, stderr, status = run_executable

      expect([status.success?, stdout, stderr])
        .to match([false, '', %r{Error:.*Usage: bin/release/prepare VERSION}m])
    end

    # An unbundled environment keeps Bundler's RUBYOPT out of the child
    # process, whose stderr must contain only the executable's own output.
    def run_executable(*arguments)
      Bundler.with_unbundled_env { Open3.capture3(RbConfig.ruby, PrepareSpecSupport::EXECUTABLE, *arguments) }
    end
  end

  def dirty_tree_failure
    [
      'Working tree must be clean before preparing a release',
      [%w[git symbolic-ref --quiet --short HEAD], %w[git status --porcelain=v1]],
      []
    ]
  end

  def untracked_tree_failure
    [
      'Working tree must be clean before preparing a release',
      [%w[git symbolic-ref --quiet --short HEAD], %w[git status --porcelain=v1]],
      PrepareSpecSupport::CURRENT_VERSION_CONTENTS,
      PrepareSpecSupport::CHANGELOG_CONTENTS
    ]
  end

  def release_temp_files
    Dir.glob(File.join(root, '**', '.*.release-*'))
  end

  def with_read_only(path)
    File.chmod(0o555, path)
    yield
  ensure
    File.chmod(0o755, path)
  end

  def changelog_with_existing_heading
    PrepareSpecSupport::CHANGELOG_CONTENTS.sub(
      '## [1.2.2]',
      "## [1.2.3] - 2026-07-01\n\n## [1.2.2]"
    )
  end

  def changelog_without_release_heading
    <<~MARKDOWN
      # Changelog

      ## [Unreleased]

      [Unreleased]: https://github.com/dominicsayers/url_canonicalize/compare/v1.2.2...HEAD
      [1.2.2]: https://github.com/dominicsayers/url_canonicalize/compare/v1.2.1...v1.2.2
    MARKDOWN
  end
end
# rubocop:enable RSpec/SpecFilePathFormat
