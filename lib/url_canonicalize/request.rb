# frozen_string_literal: true

module URLCanonicalize
  # Make an HTTP request
  class Request
    NETWORK_EXCEPTIONS = [
      EOFError,
      Errno::ECONNREFUSED,
      Errno::ECONNRESET,
      Errno::EHOSTUNREACH,
      Errno::EINVAL,
      Errno::ENETUNREACH,
      Errno::ETIMEDOUT,
      Net::OpenTimeout,
      Net::ReadTimeout,
      OpenSSL::SSL::SSLError,
      SocketError,
      Timeout::Error,
      Zlib::BufError,
      Zlib::DataError
    ].freeze

    # Unsuccessful responses to a HEAD request that trigger a retry with GET
    HEAD_FALLBACK_RESPONSES = [
      Net::HTTPForbidden,
      Net::HTTPMethodNotAllowed,
      Net::HTTPNotImplemented
    ].freeze

    def fetch
      handle_response
    end

    def location
      @location ||= relative_to_absolute(response['location'])
    end

    # Point this request at a new URI, discarding all state from the previous
    # response so nothing leaks between hops
    def with_uri(uri)
      @uri = uri

      @url = nil
      self.http_method = @default_http_method

      self
    end

    private

    attr_reader :http, :http_method

    def initialize(http, http_method = :head)
      @http = http
      @http_method = http_method
      @default_http_method = http_method
    end

    def response
      @response ||= do_http_request
    end

    # We can stub this method in testing then call #response any number of times
    def do_http_request # :nodoc: internal use only
      http.do_request request # Some URLs can throw an exception here
    end

    def request
      @request ||= request_for_method
    end

    def handle_response
      log_response

      case response
      when Net::HTTPSuccess
        handle_success
      when Net::HTTPRedirection
        handle_redirection
      else
        handle_unsuccessful
      end
    rescue *NETWORK_EXCEPTIONS => e
      handle_failure(e.class, e.message, e)
    end

    def handle_success
      @canonical_url = normalized(relative_to_absolute(URLCanonicalize::LinkHeader.canonical(response)))

      return enhanced_response if canonical_url || http_method == :get

      fallback_to_get
    end

    # Some servers reject HEAD requests outright, so any HEAD request rejected
    # with one of these statuses is retried as a GET before giving up
    def handle_unsuccessful
      return fallback_to_get if http_method == :head && HEAD_FALLBACK_RESPONSES.any? { |klass| response.is_a?(klass) }

      handle_failure
    end

    def fallback_to_get
      self.http_method = :get
      fetch
    end

    # Follow any redirection that carries a usable Location header, whether the
    # redirect is temporary or permanent. A redirection without one cannot be
    # followed, so it is reported as a failure.
    def handle_redirection
      if location
        URLCanonicalize::Response::Redirect.new(location)
      else
        URLCanonicalize::Response::Failure.new(::URI::InvalidURIError, response['location'])
      end
    end

    def handle_failure(klass = response.class, message = response.message, error = nil)
      URLCanonicalize::Response::Failure.new(klass, message, error)
    end

    def enhanced_response
      if canonical_url
        logger&.debug { "canonical_url: #{canonical_url}" }
        response_plus = URLCanonicalize::Response::Success.new(canonical_url, response, html)
        URLCanonicalize::Response::CanonicalFound.new(canonical_url, response_plus)
      else
        URLCanonicalize::Response::Success.new(url, response, html)
      end
    end

    def html
      @html ||= Nokogiri::HTML(response.body) if URLCanonicalize::MediaType.html?(response)
    end

    def canonical_url
      @canonical_url ||= normalized(relative_to_absolute(canonical_url_element&.[]('href'), document_base_url))
    end

    # Declared canonical URLs are returned to callers, so they get the same
    # syntactic normalization as every requested URL
    def normalized(url)
      URLCanonicalize::URI.normalize(url) if url
    end

    # The first HTML link element whose rel tokens include "canonical", however
    # the tokens are cased, provided it has a usable href
    def canonical_url_element
      @canonical_url_element ||= html&.css('head link[rel]')&.find do |element|
        element['rel'].split.any? { |token| token.casecmp?('canonical') } && !element['href'].to_s.strip.empty?
      end
    end

    # HTML canonical links resolve against the document base URL, not the
    # request URL, when the document declares one
    def document_base_url
      base_href = html&.at_css('head base[href]')&.[]('href')
      relative_to_absolute(base_href) || url
    end

    def uri
      @uri ||= http.uri
    end

    def url
      @url ||= uri.to_s
    end

    def request_for_method
      r = base_request
      headers.each { |header_key, header_value| r[header_key] = header_value }
      r
    end

    def base_request
      case http_method
      when :head
        Net::HTTP::Head.new uri
      when :get
        Net::HTTP::Get.new uri
      else
        raise URLCanonicalize::Exception::Request, "Unknown method: #{http_method}"
      end
    end

    def headers
      http.options[:headers]
    end

    def http_method=(value)
      @http_method = value
      @request = nil
      @response = nil
      @location = nil
      @html = nil
      @canonical_url = nil
      @canonical_url_element = nil
    end

    # Resolve absolute, protocol-relative, root-relative, path-relative and
    # query-only references against the base URL per RFC 3986. Only http(s)
    # results are usable
    def relative_to_absolute(reference, base = url)
      return unless reference

      absolute = ::URI.join(base, reference.strip)
      absolute.to_s if absolute.is_a?(::URI::HTTP)
    rescue ::URI::InvalidURIError, ArgumentError, Encoding::CompatibilityError
      nil
    end

    def log_response
      logger&.debug { "#{http_method.upcase} #{url} #{response.code} #{response.message}" }
    end

    def logger
      http.options[:logger]
    end
  end
end
