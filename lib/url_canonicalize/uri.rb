# frozen_string_literal: true

module URLCanonicalize
  # Parses and normalizes URLs with local exception handling
  class URI
    class << self
      VALID_CLASSES = [::URI::HTTP, ::URI::HTTPS].freeze

      # A scheme is recognized only as a leading scheme: token; a colon
      # anywhere else no longer suppresses the default scheme
      SCHEME = /\A[A-Za-z][A-Za-z0-9+.-]*:/

      def parse(url)
        uri = ::URI.parse normalize(url)
        validate! uri
        uri
      rescue ::URI::InvalidURIError => e
        raise URLCanonicalize::Exception::URI, "#{e.class}: #{e.message}" # the original error becomes the cause
      end

      # Syntactic normalization per RFC 3986, via Addressable: lowercase
      # scheme and host, internationalized hosts to punycode, uppercase
      # percent-encodings with unreserved characters decoded, dot segments
      # resolved, default ports removed and the empty path replaced by "/".
      # Fragments are client-side state, so no canonical URL carries one
      def normalize(url)
        addressable = Addressable::URI.parse(decorate(url.to_s.strip)).normalize
        addressable.fragment = nil
        addressable.to_s
      rescue Addressable::URI::InvalidURIError, ArgumentError, Encoding::CompatibilityError => e
        raise URLCanonicalize::Exception::URI, "#{e.class}: #{e.message}" # the original error becomes the cause
      end

      private

      def validate!(uri)
        raise URLCanonicalize::Exception::URI, "#{uri} must be http or https" unless VALID_CLASSES.include?(uri.class)
        raise URLCanonicalize::Exception::URI, "Missing host name in #{uri}" unless uri.host
        raise URLCanonicalize::Exception::URI, "Empty host name in #{uri}" if uri.host.empty?
      end

      def decorate(url)
        return url if url.match?(SCHEME)

        "http://#{url}" # Add protocol if we just receive a host name
      end
    end
  end
end
