module URLCanonicalize
  # Manage the URL into a URI with local exception handling
  class URI
    class << self
      def parse(url)
        uri = ::URI.parse(url)
        uri if valid?(uri)
      rescue ::URI::InvalidURIError => e
        new_exception = URLCanonicalize::Exception::URI.new("#{e.class}: #{e.message}")
        new_exception.set_backtrace e.backtrace
        raise new_exception
      end

      private

      def valid?(uri)
        raise URLCanonicalize::Exception::URI, "#{uri} must be http or https" unless VALID_CLASSES.include?(uri.class)
        raise URLCanonicalize::Exception::URI, "Missing host name in #{uri}" unless uri.host
        true
      end

      VALID_CLASSES = [::URI::HTTP, ::URI::HTTPS].freeze
    end
  end
end
