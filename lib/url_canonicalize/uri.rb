# frozen_string_literal: true

module URLCanonicalize
  # Manage the URL into a URI with local exception handling
  class URI
    class << self
      VALID_CLASSES = [::URI::HTTP, ::URI::HTTPS].freeze
      COLON = ':'

      def parse(url)
        uri = ::URI.parse decorate(url)
        validate! uri
        uri
      rescue ::URI::InvalidURIError => e
        raise URLCanonicalize::Exception::URI, "#{e.class}: #{e.message}" # the original error becomes the cause
      end

      private

      def validate!(uri)
        raise URLCanonicalize::Exception::URI, "#{uri} must be http or https" unless VALID_CLASSES.include?(uri.class)
        raise URLCanonicalize::Exception::URI, "Missing host name in #{uri}" unless uri.host
        raise URLCanonicalize::Exception::URI, "Empty host name in #{uri}" if uri.host.empty?
      end

      def decorate(url)
        return url if url.include? COLON

        "http://#{url}" # Add protocol if we just receive a host name
      end
    end
  end
end
