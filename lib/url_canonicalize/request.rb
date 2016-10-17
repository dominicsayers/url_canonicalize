module URLCanonicalize
  # Make an HTTP request
  class Request
    def fetch
    end

    private

    def initialize(http, uri)
      @http = http
      @uri = uri
    end
  end
end
