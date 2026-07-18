# frozen_string_literal: true

require 'rbconfig'
require 'stringio'
require 'spec_helper'
require 'tmpdir'
require_relative '../../../bin/release/support'

# This support file intentionally specifies its two public classes together.
# rubocop:disable RSpec/MultipleDescribes
RSpec.describe ReleaseTools::Version do
  let(:invalid_versions) do
    [
      '1.2',
      'v1.2.3',
      '01.2.3',
      '1.02.3',
      '1.2.03',
      '1.2.3-rc1',
      '1.2.3+build.1',
      12_003,
      nil
    ]
  end

  describe '.parse' do
    it 'accepts stable semantic versions without leading zeroes' do
      expect(described_class.parse('0.1.23').to_s).to eq('0.1.23')
    end

    it 'rejects malformed and non-string versions' do
      invalid_versions.each do |version|
        expect { described_class.parse(version) }
          .to raise_error(ReleaseTools::Error, 'Version must use the X.Y.Z format')
      end
    end
  end

  describe '#to_s' do
    it 'returns the original version string' do
      expect(described_class.parse('12.34.56').to_s).to eq('12.34.56')
    end
  end

  describe '#tag' do
    it 'prefixes the version with v' do
      expect(described_class.parse('1.2.3').tag).to eq('v1.2.3')
    end
  end

  describe 'ordering' do
    it 'uses numeric gem version ordering' do
      versions = %w[2.0.0 1.10.0 1.9.0].map { |version| described_class.parse(version) }

      expect(versions.sort.map(&:to_s)).to eq(%w[1.9.0 1.10.0 2.0.0])
    end
  end
end

RSpec.describe ReleaseTools::Runner do
  let(:stdout) { StringIO.new }
  let(:stderr) { StringIO.new }
  let(:sleep_durations) { [] }
  let(:sleeper) do
    durations = sleep_durations
    Object.new.tap do |object|
      object.define_singleton_method(:sleep) { |duration| durations << duration }
    end
  end
  let(:runner) do
    described_class.new(
      stdout: stdout,
      stderr: stderr,
      stdin: StringIO.new("yes\n"),
      sleeper: sleeper
    )
  end

  def expect_single_string_rejection_for(method_name, with_options: false)
    Dir.mktmpdir do |directory|
      redirection_target = File.join(directory, 'shell-created-file')
      command = ["printf unsafe > #{redirection_target}"]
      command << {} if with_options
      aggregate_failures do
        expect { runner.public_send(method_name, *command) }
          .to raise_error(ReleaseTools::Error, 'Command must be provided as an executable and separate arguments')
        expect(File.exist?(redirection_target)).to be(false)
      end
    end
  end

  describe '#capture' do
    it 'returns stdout from a successful command' do
      output = runner.capture(RbConfig.ruby, '-e', 'STDOUT.write ARGV.fetch(0)', 'captured output')

      expect(output).to eq('captured output')
    end

    it 'passes each command argument directly without shell interpretation' do
      shell_syntax = '$(printf unsafe); echo still-an-argument'

      output = runner.capture(RbConfig.ruby, '-e', 'STDOUT.write ARGV.fetch(0)', shell_syntax)

      expect(output).to eq(shell_syntax)
    end

    it 'raises an informative error when the command fails' do
      command = [RbConfig.ruby, '-e', "STDERR.write('specific failure'); exit 7"]

      expect { runner.capture(*command) }
        .to raise_error(ReleaseTools::Error, /Command failed:.*#{Regexp.escape(RbConfig.ruby)}.*specific failure/m)
    end

    it 'rejects a single command string without invoking a shell' do
      expect_single_string_rejection_for(:capture)
    end

    it 'rejects a shell string accompanied only by process options' do
      expect_single_string_rejection_for(:capture, with_options: true)
    end

    it 'wraps missing executable errors with command context' do
      Dir.mktmpdir do |directory|
        missing_executable = File.join(directory, 'missing-command')

        expect { runner.capture(missing_executable, '--version') }
          .to raise_error(ReleaseTools::Error, /Command could not be executed:.*missing-command.*No such file/m)
      end
    end
  end

  describe '#run' do
    it 'returns true when a passthrough command succeeds' do
      expect(runner.run(RbConfig.ruby, '-e', 'exit 0')).to be(true)
    end

    it 'passes each command argument directly without shell interpretation' do
      shell_syntax = '$(exit 9); ignored-by-a-shell'
      ruby_code = 'exit ARGV.fetch(0) == ARGV.fetch(1) ? 0 : 1'

      expect(runner.run(RbConfig.ruby, '-e', ruby_code, shell_syntax, shell_syntax)).to be(true)
    end

    it 'raises a clear error when the command fails' do
      expect { runner.run(RbConfig.ruby, '-e', 'exit 9') }
        .to raise_error(ReleaseTools::Error, /Command failed:.*#{Regexp.escape(RbConfig.ruby)}/m)
    end

    it 'rejects a single command string without invoking a shell' do
      expect_single_string_rejection_for(:run)
    end

    it 'rejects a shell string accompanied only by process options' do
      expect_single_string_rejection_for(:run, with_options: true)
    end

    it 'reports missing executables with command context' do
      Dir.mktmpdir do |directory|
        missing_executable = File.join(directory, 'missing-command')

        expect { runner.run(missing_executable, '--version') }
          .to raise_error(ReleaseTools::Error, /Command could not be executed:.*missing-command/m)
      end
    end
  end

  describe 'injected collaborators' do
    it 'writes messages to the injected stdout' do
      runner.puts('normal message')
      runner.print('prompt: ')

      expect(stdout.string).to eq("normal message\nprompt: ")
    end

    it 'writes warnings to the injected stderr' do
      runner.warn('warning message')

      expect(stderr.string).to eq("warning message\n")
    end

    it 'reads from the injected input stream' do
      expect(runner.gets).to eq("yes\n")
    end

    it 'sleeps through the injected sleeper' do
      runner.sleep(1.5)

      expect(sleep_durations).to eq([1.5])
    end
  end
end
# rubocop:enable RSpec/MultipleDescribes
