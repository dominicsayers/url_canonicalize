module URLCanonicalize
  # Manage the URL into a URI with local exception handling
  class URI
    def valid?
      raise Exception::URI, "#{@url} must be http or https" unless VALID_CLASSES.include?(uri.class)
      raise Exception::URI, "Missing host name in #{@url}" unless uri.host
      true
    end

    def to_s
      @to_s ||= uri.to_s
    end

    private

    VALID_CLASSES = [::URI::HTTP, ::URI::HTTPS].freeze

    def initialize(url)
      @url = url
      valid?
    end

    def uri
      @uri ||= ::URI.parse @url
    rescue ::URI::InvalidURIError, ArgumentError => e
      raise Exception::URI, "#{e.class}: #{e.message}"
    end
  end
end
