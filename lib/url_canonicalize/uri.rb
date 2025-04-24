# frozen_string_literal: true

module URLCanonicalize
  # Manage the URL into a URI with local exception handling
  class URI
    class << self
      VALID_CLASSES = [::URI::HTTP, ::URI::HTTPS].freeze
      COLON = ':'

      def parse(url)
        uri = ::URI.parse decorate(url)
        uri if valid? uri
      rescue ::URI::InvalidURIError => e
        new_exception = URLCanonicalize::Exception::URI.new("#{e.class}: #{e.message}")
        new_exception.set_backtrace e.backtrace
        raise new_exception
      end

      private

      def valid?(uri)
        raise URLCanonicalize::Exception::URI, "#{uri} must be http or https" unless VALID_CLASSES.include?(uri.class)
        raise URLCanonicalize::Exception::URI, "Missing host name in #{uri}" unless uri.host
        raise URLCanonicalize::Exception::URI, "Empty host name in #{uri}" if uri.host.empty?

        true
      end

      def decorate(url)
        return url if url.include? COLON

        "http://#{url}" # Add protocol if we just receive a host name
      end
    end
  end
end
