# frozen_string_literal: true

module URLCanonicalize
  # A reusable canonicalization client. The options are validated and frozen
  # at construction, so one client can be shared safely between threads
  class Client
    attr_reader :options

    def initialize(**values)
      @options = URLCanonicalize::Options.new(**values)
    end

    def canonicalize(url)
      fetch(url).url
    end

    def fetch(url)
      URLCanonicalize::HTTP.new(url, options: options).fetch
    end
  end
end
