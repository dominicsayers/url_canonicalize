# frozen_string_literal: true

require 'open3'
require 'rubygems/version'
require 'shellwords'

module ReleaseTools
  class Error < StandardError; end

  class Version
    include Comparable

    PATTERN = /\A(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)\z/
    ERROR_MESSAGE = 'Version must use the X.Y.Z format'

    class << self
      def parse(value)
        raise Error, ERROR_MESSAGE unless value.is_a?(String) && PATTERN.match?(value)

        new(value)
      end

      private :new
    end

    def initialize(value)
      @value = value
      @gem_version = Gem::Version.new(value)
    end

    def <=>(other)
      return unless other.is_a?(self.class)

      gem_version <=> other.gem_version
    end

    def to_s
      value
    end

    def tag
      "v#{value}"
    end

    protected

    attr_reader :gem_version

    private

    attr_reader :value
  end

  class Runner
    def initialize(stdout: $stdout, stderr: $stderr, stdin: $stdin, sleeper: Kernel)
      @stdout = stdout
      @stderr = stderr
      @stdin = stdin
      @sleeper = sleeper
    end

    def capture(*command)
      validate_command!(command)
      captured_stdout, captured_stderr, status = Open3.capture3(*command)
      return captured_stdout if status.success?

      raise_command_error(command, captured_stderr)
    rescue SystemCallError => e
      raise_spawn_error(command, e.message)
    end

    def run(*command)
      validate_command!(command)
      result = system(*command)
      return true if result

      result.nil? ? raise_spawn_error(command) : raise_command_error(command)
    rescue SystemCallError => e
      raise_spawn_error(command, e.message)
    end

    def puts(message = '')
      @stdout.puts(message)
    end

    def print(message)
      @stdout.print(message)
    end

    def warn(message)
      @stderr.puts(message)
    end

    def gets
      @stdin.gets
    end

    def sleep(duration)
      @sleeper.sleep(duration)
    end

    private

    def validate_command!(command)
      return if command.length > 1 && command.all?(String)

      raise Error, 'Command must be provided as an executable and separate arguments'
    end

    def raise_command_error(command, captured_stderr = nil)
      message = "Command failed: #{Shellwords.join(command.map(&:to_s))}"
      message = "#{message}\n#{captured_stderr.strip}" unless captured_stderr.to_s.strip.empty?
      raise Error, message
    end

    def raise_spawn_error(command, details = 'Executable was not found')
      message = "Command could not be executed: #{Shellwords.join(command.map(&:to_s))}"
      raise Error, "#{message}\n#{details}"
    end
  end
end
