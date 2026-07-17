# frozen_string_literal: true

module URLCanonicalize
  # Normalizes response media types for safe buffering and parsing decisions
  module MediaType
    HTML = %w[text/html application/xhtml+xml].freeze
    BUFFERED = (HTML + %w[application/xml text/xml]).freeze

    module_function

    def buffered?(response)
      BUFFERED.include?(normalized(response))
    end

    def html?(response)
      HTML.include?(normalized(response))
    end

    def normalized(response)
      response['content-type'].to_s.split(';', 2).first.to_s.strip.downcase
    end
  end
end
