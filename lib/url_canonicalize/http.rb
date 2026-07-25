# frozen_string_literal: true

module URLCanonicalize
  # Persistent connection for possible repeated requests to the same host
  class HTTP
    def fetch
      final = ::Timeout.timeout(
        options[:total_timeout],
        URLCanonicalize::Exception::Timeout,
        "Canonicalization exceeded #{options[:total_timeout]} seconds"
      ) { fetch_within_deadline }
      build_result(final)
    end

    def uri
      @uri ||= URLCanonicalize::URI.parse(url) # Malformed URLs will raise a URLCanonicalize exception
    end

    def url=(value)
      @url = value.to_s
      @uri = nil
    end

    def do_request(http_request)
      http.request(http_request) { |response| read_response_body(http_request, response) }
    end

    attr_reader :options

    private

    attr_accessor :last_known_good

    def initialize(raw_url, options: nil, **values)
      raise ArgumentError, 'Pass either options: or keyword options, not both' if options && !values.empty?

      @raw_url = raw_url
      @options = options || URLCanonicalize::Options.new(**values)
    end

    def build_result(final)
      Result.new(url: final.url, response: final.response, html: final.html, chain: chain, source: @final_source)
    end

    def fetch_within_deadline
      loop do
        result = handle_response
        break result if result
      end
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

    # Parse the response, and clear the response ready to follow the next redirect.
    # Returns the final response when canonicalization is complete, or nil to continue
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
        handle_redirect
      when URLCanonicalize::Response::CanonicalFound
        handle_canonical_found
      when URLCanonicalize::Response::Failure
        handle_failure
      else
        handle_unhandled_response
      end
    end

    def handle_redirect
      reason = hop_refusal_reason
      return follow_hop(:redirect) unless reason

      finish_with_last_known_good || raise(URLCanonicalize::Exception::Redirect, reason)
    end

    def handle_canonical_found
      self.last_known_good = response.response
      return finish_with_last_known_good if hop_refusal_reason

      follow_hop(:canonical_link)
    end

    # A terminal response whose URL came from a server-declared canonical link
    def finish_with_last_known_good
      return unless last_known_good

      @final_source = :canonical_link
      last_known_good
    end

    # Redirects and followed canonical links share one visited-URL set and one
    # hop budget, so any cycle or over-long chain terminates deterministically
    def hop_refusal_reason
      return 'Redirect loop detected' if visited?(response_url)
      return "#{hops + 1} redirects is too many" if hops >= options[:max_redirects]

      nil
    end

    def follow_hop(via)
      chain << Result::Hop.new(url: response_url, via: via)
      self.url = response_url
      nil
    end

    # The URLs requested so far and how each one was discovered
    def chain
      @chain ||= [Result::Hop.new(url: url, via: :initial)]
    end

    def visited?(candidate)
      chain.any? { |hop| hop.url == candidate }
    end

    def hops
      chain.length - 1
    end

    def handle_failure
      finish_with_last_known_good || raise(
        URLCanonicalize::Exception::Failure,
        "#{response.failure_class}: #{response.message}",
        cause: response.error
      )
    end

    def handle_unhandled_response
      raise URLCanonicalize::Exception::Failure, "Unhandled response type: #{response.class}"
    end

    def handle_success
      @final_source = chain.last.via
      self.last_known_good = response
    end

    def url
      @url ||= @raw_url.to_s
    end

    def http
      URLCanonicalize::Destination.validate!(uri, options)
      return @http if same_origin? # reuse connection

      @previous = uri
      @http = options[:transport].call(uri, options)
    end

    def same_origin?
      uri.scheme == previous.scheme && uri.host == previous.host && uri.port == previous.port
    end

    def previous
      @previous ||= Struct.new(:scheme, :host, :port).new
    end

    def read_response_body(http_request, response)
      if buffer_response_body?(http_request, response)
        enforce_content_length!(response)
        response.read_body(URLCanonicalize::BoundedBody.new(options[:max_body_bytes]))
      else
        response.read_body { |_chunk| nil }
      end
    end

    def buffer_response_body?(http_request, response)
      http_request.method == 'GET' && response.is_a?(Net::HTTPSuccess) && URLCanonicalize::MediaType.buffered?(response)
    end

    def enforce_content_length!(response)
      return unless response.content_length && response.content_length > options[:max_body_bytes]

      raise URLCanonicalize::Exception::ResponseTooLarge,
            "Response body exceeds #{options[:max_body_bytes]} bytes"
    end
  end
end
