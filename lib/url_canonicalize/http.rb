module URLCanonicalize
  # Persistent connection for possible repeated requests to the same host
  class HTTP
    def fetch
      loop do
        break response if response.is_a?(Net::HTTPSuccess)
        increment_redirect_counter
      end
    end

    private

    def initialize(raw_url)
      @raw_url = raw_url
    end

    def response
      @response ||= URLCanonicalize::Request.new(self, uri).fetch
    end

    def increment_redirect_counter
      @redirects = (@redirects || 0) + 1
      raise Exception::Redirect, "#{@redirects} redirects is too many" if @redirects > options[:max_redirects]
    end

    def url
      @url ||= @raw_url.to_s
    end

    def uri
      @uri ||= URLCanonicalize::URI.new(url) # Malformed URLs will raise a URLCanonicalize exception
    end

    def http
      return @http if same_host_and_port # reuse connection

      @previous = uri
      @http = Net::HTTP.new uri.host, uri.port
    end

    def same_host_and_port
      uri.host == previous.host && uri.port == previous.port
    end

    def previous
      @previous ||= Struct.new(:host, :port).new
    end

    def options
      @options ||= {
        max_redirects: 10
      }
    end
  end
end
