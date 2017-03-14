# frozen_string_literal: true
module URLCanonicalize
  # Make an HTTP request
  class Request
    def fetch
      handle_response
    end

    def location
      @location ||= relative_to_absolute(response['location'])
    end

    def with_uri(uri)
      @uri = uri

      @url = nil
      @host = nil
      @request = nil
      @response = nil
      @location = nil
      @html = nil

      self
    end

    private

    attr_reader :http, :http_method

    def initialize(http, http_method = :head)
      @http = http
      @http_method = http_method
    end

    def response
      @response ||= do_http_request
    end

    # We can stub this method in testing then call #response any number of times
    def do_http_request #:nodoc: internal use only
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
        handle_failure
      end
    rescue *NETWORK_EXCEPTIONS => e
      handle_failure(e.class, e.message)
    end

    def handle_success
      @canonical_url = $LAST_MATCH_INFO['url'] if (response['link'] || '') =~ /<(?<url>.+)>\s*;\s*rel="canonical"/i

      return enhanced_response if canonical_url || http_method == :get

      self.http_method = :get
      fetch
    end

    def handle_redirection
      case response
      when Net::HTTPFound, Net::HTTPMovedTemporarily, Net::HTTPTemporaryRedirect # Temporary redirection
        handle_success
      else # Permanent redirection
        if location
          URLCanonicalize::Response::Redirect.new(location)
        else
          URLCanonicalize::Response::Failure.new(::URI::InvalidURIError, response['location'])
        end
      end
    end

    def handle_failure(klass = response.class, message = response.message)
      URLCanonicalize::Response::Failure.new(klass, message)
    end

    def enhanced_response
      if canonical_url
        puts "  * canonical_url:\t#{canonical_url}" if ENV['DEBUG']
        response_plus = URLCanonicalize::Response::Success.new(canonical_url, response, html)
        URLCanonicalize::Response::CanonicalFound.new(canonical_url, response_plus)
      else
        URLCanonicalize::Response::Success.new(url, response, html)
      end
    end

    def html
      @html ||= Nokogiri::HTML response.body
    end

    def canonical_url
      @canonical_url ||= relative_to_absolute(canonical_url_raw)
    end

    def canonical_url_raw
      @canonical_url ||= canonical_url_element['href'] if canonical_url_element.is_a?(Nokogiri::XML::Element)
    end

    def canonical_url_element
      @canonical_url_element ||= html.xpath('//head/link[@rel="canonical"]').first
    end

    def uri
      @uri ||= http.uri
    end

    def url
      @url ||= uri.to_s
    end

    def host
      @host ||= uri.host
    end

    def request_for_method
      r = base_request
      headers.each { |header_key, header_value| r[header_key] = header_value }
      r
    end

    def base_request
      check_http_method

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
      @headers ||= {
        'Accept-Language' => 'en-US,en;q=0.8',
        'User-Agent' => 'Mozilla/5.0 (Windows NT 10.0; WOW64) '\
                        'AppleWebKit/537.36 (KHTML, like Gecko) '\
                        'Chrome/51.0.2704.103 Safari/537.36'
      }
    end

    def http_method=(value)
      @http_method = value
      @request = nil
      @response = nil
      @location = nil
      @html = nil
    end

    # Some sites treat HEAD requests as suspicious activity and block the
    # requester after a few attempts. For these sites we'll use GET requests
    # only
    def check_http_method
      @http_method = :get if /(linkedin|crunchbase).com/ =~ host
    end

    def relative_to_absolute(partial_url)
      return unless partial_url
      partial_uri = ::URI.parse(partial_url)

      if partial_uri.host
        partial_url # It's already absolute
      else
        ::URI.join((uri || url), partial_url).to_s
      end
    rescue ::URI::InvalidURIError
      nil
    end

    def log_response
      return unless ENV['DEBUG']
      puts "#{http_method.upcase} #{url} #{response.code} #{response.message}"

      return unless ENV['DEBUG'].casecmp('headers')
      response.each { |k, v| puts "  #{k}:\t#{v}" }
    end

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
  end
end
