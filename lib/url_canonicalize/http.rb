# frozen_string_literal: true
module URLCanonicalize
  # Persistent connection for possible repeated requests to the same host
  class HTTP
    def fetch
      loop { break last_known_good if handle_response }
    end

    def uri
      @uri ||= URLCanonicalize::URI.parse(url) # Malformed URLs will raise a URLCanonicalize exception
    end

    def url=(value)
      @url = value.to_s
      @uri = nil
    end

    def do_request(http_request)
      http.request http_request
    end

    private

    attr_accessor :last_known_good

    def initialize(raw_url)
      @raw_url = raw_url
    end

    # Fetch the response
    def response
      @response ||= fetch_response
    end

    def response_url
      @response_url ||= response.url
    end

    def request
      @request ||= Request.new(self)
    end

    def fetch_response
      request.with_uri(uri).fetch
    end

    # Parse the response, and clear the response ready to follow the next redirect
    def handle_response
      result = parse_response
      @response = nil
      @response_url = nil
      result
    end

    # Parse the response
    def parse_response
      case response
      when URLCanonicalize::Response::Success
        handle_success
      when URLCanonicalize::Response::Redirect
        redirect_loop_detected? || max_redirects_reached?
      when URLCanonicalize::Response::CanonicalFound
        handle_canonical_found
      when URLCanonicalize::Response::Failure
        handle_failure
      else
        handle_unhandled_response
      end
    end

    def redirect_loop_detected?
      if redirect_list.include?(response_url)
        return true if last_known_good
        raise URLCanonicalize::Exception::Redirect, 'Redirect loop detected'
      end

      redirect_list << response_url
      increment_redirects
      set_url_from_response
      false
    end

    def max_redirects_reached?
      return false unless @redirects > options[:max_redirects]
      return true if last_known_good
      raise URLCanonicalize::Exception::Redirect, "#{@redirects} redirects is too many"
    end

    def redirect_list
      @redirect_list ||= []
    end

    def increment_redirects
      @redirects = redirects + 1
    end

    def redirects
      @redirects ||= 0
    end

    def handle_canonical_found
      self.last_known_good = response.response
      return true if response_url == url || redirect_list.include?(response_url)
      set_url_from_response
      false
    end

    def set_url_from_response
      self.url = response_url
    end

    def handle_failure
      return true if last_known_good
      raise URLCanonicalize::Exception::Failure, "#{response.failure_class}: #{response.message}"
    end

    def handle_unhandled_response
      raise URLCanonicalize::Exception::Failure, "Unhandled response type: #{response.class}"
    end

    def handle_success
      self.last_known_good = response
      true
    end

    def url
      @url ||= @raw_url.to_s
    end

    def http
      return @http if same_host_and_port # reuse connection

      @previous = uri
      @http = new_http
    end

    def same_host_and_port
      uri.host == previous.host && uri.port == previous.port
    end

    def previous
      @previous ||= Struct.new(:host, :port).new
    end

    def new_http
      h = Net::HTTP.new uri.host, uri.port

      h.open_timeout = options[:open_timeout]
      h.read_timeout = options[:read_timeout]

      if uri.scheme == 'https'
        h.use_ssl = true # Can generate exception
        h.verify_mode = OpenSSL::SSL::VERIFY_NONE
      else
        h.use_ssl = false
      end

      h
    end

    def options
      @options ||= {
        open_timeout: 8, # Twitter responds in >5s
        read_timeout: 15,
        max_redirects: 10
      }
    end
  end
end
