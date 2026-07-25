# frozen_string_literal: true

module URLCanonicalize
  # Builds the connection for a destination, resolving the host through the
  # fetch security policy. Injectable via the :transport option: anything
  # responding to call(uri, options) and returning a Net::HTTP-compatible
  # connection can replace it
  class Transport
    # Resolved lazily so the destination policy can be stubbed in tests
    DEFAULT_RESOLVER = lambda do |uri, options|
      URLCanonicalize::Destination.resolve(uri, options)
    end

    def initialize(resolver: DEFAULT_RESOLVER)
      @resolver = resolver
      freeze
    end

    def call(uri, options)
      http = Net::HTTP.new(uri.host, uri.port, nil)

      http.ipaddr = @resolver.call(uri, options)
      configure_timeouts(http, options)
      configure_tls(http, uri)

      http
    end

    private

    def configure_timeouts(http, options)
      http.open_timeout = options[:open_timeout]
      http.read_timeout = options[:read_timeout]
      http.write_timeout = options[:write_timeout]
    end

    def configure_tls(http, uri)
      if uri.scheme == 'https'
        http.use_ssl = true # Can generate exception
        http.verify_mode = OpenSSL::SSL::VERIFY_PEER
        http.verify_hostname = true
      else
        http.use_ssl = false
      end
    end
  end
end
