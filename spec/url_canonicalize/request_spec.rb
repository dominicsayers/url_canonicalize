# frozen_string_literal: true

describe URLCanonicalize::Request do
  context 'response types' do
    {
      '301' => Net::HTTPMovedPermanently,
      '302' => Net::HTTPFound,
      '303' => Net::HTTPSeeOther,
      '307' => Net::HTTPTemporaryRedirect,
      '308' => Net::HTTPPermanentRedirect
    }.each do |code, response_class|
      it "follows a #{code} redirection" do
        url = 'http://twitter.com'
        location = 'https://twitter.com/'
        http = URLCanonicalize::HTTP.new(url)
        request = described_class.new(http)
        response = response_class.new('1.1', code, '')
        response['location'] = location

        allow(request).to receive(:do_http_request).and_return(response)

        result = request.with_uri(URLCanonicalize::URI.parse(url)).fetch

        expect(result).to be_a(URLCanonicalize::Response::Redirect)
        expect(result.url).to eq(location)
      end
    end

    it 'resolves a protocol-relative redirect location' do
      result = redirect_from('https://twitter.com', location: '//other.example/path')

      expect(result).to be_a(URLCanonicalize::Response::Redirect)
      expect(result.url).to eq('https://other.example/path')
    end

    it 'resolves a query-only redirect location' do
      result = redirect_from('http://twitter.com/page', location: '?q=1')

      expect(result).to be_a(URLCanonicalize::Response::Redirect)
      expect(result.url).to eq('http://twitter.com/page?q=1')
    end

    it 'treats a redirect to a non-HTTP location as a failure' do
      expect(redirect_from('http://twitter.com', location: 'ftp://example.com/file'))
        .to be_a(URLCanonicalize::Response::Failure)
    end

    def redirect_from(url, location:)
      http = URLCanonicalize::HTTP.new(url)
      request = described_class.new(http)
      response = Net::HTTPMovedPermanently.new('1.1', '301', '')
      response['location'] = location
      allow(request).to receive(:do_http_request).and_return(response)
      request.with_uri(URLCanonicalize::URI.parse(url)).fetch
    end

    it 'treats a redirection without a Location header as a failure' do
      url = 'http://twitter.com'
      http = URLCanonicalize::HTTP.new(url)
      request = described_class.new(http)
      response = Net::HTTPFound.new('1.1', '302', '')

      allow(request).to receive(:do_http_request).and_return(response)

      expect(request.with_uri(URLCanonicalize::URI.parse(url)).fetch)
        .to be_a(URLCanonicalize::Response::Failure)
    end

    it 'logs the response if required' do
      url = 'https://twitter.com'
      http = URLCanonicalize::HTTP.new(url)
      request = described_class.new(http)
      responses = [
        Net::HTTPOK.new('1.1', '200', ''),
        Net::HTTPOK.new('1.1', '200', '')
      ]

      ENV['DEBUG'] = 'true'
      allow(request).to receive(:do_http_request).and_return(*responses)

      expect { request.with_uri(URLCanonicalize::URI.parse(url)).fetch }
        .to output(%r{GET https://twitter.com 200}).to_stdout
    ensure
      ENV.delete('DEBUG')
    end

    it 'follows permanent redirections' do
      url = 'http://twitter.com'
      canonical_url = 'https://twitter.com'

      http = URLCanonicalize::HTTP.new(url)
      response = Net::HTTPPermanentRedirect.new('1.1', '301', '')
      response['location'] = canonical_url
      canonical_response = Net::HTTPOK.new('1.1', '200', '')

      expect(URLCanonicalize::HTTP).to receive(:new).and_return(http)
      expect(http).to receive(:do_request).and_return(response, canonical_response, canonical_response)

      expect(URLCanonicalize.canonicalize(url)).to eq(canonical_url)
    end

    it 'follows a partial URL in a permanent redirection' do
      url = 'http://twitter.com'
      relative_path = '/relative_path'
      canonical_url = "#{url}#{relative_path}"

      http = URLCanonicalize::HTTP.new(url)
      response = Net::HTTPPermanentRedirect.new('1.1', '301', '')
      response['location'] = relative_path
      canonical_response = Net::HTTPOK.new('1.1', '200', '')

      expect(URLCanonicalize::HTTP).to receive(:new).and_return(http)
      expect(http).to receive(:do_request).and_return(response, canonical_response, canonical_response)

      expect(URLCanonicalize.canonicalize(url)).to eq(canonical_url)
    end

    it 'handles a malformed redirect' do
      url = 'http://twitter.com'
      canonical_url = "https://\xFF"

      http = URLCanonicalize::HTTP.new(url)
      response = Net::HTTPPermanentRedirect.new('1.1', '301', '')
      response['location'] = canonical_url

      expect(URLCanonicalize::HTTP).to receive(:new).and_return(http)
      expect(http).to receive(:do_request).and_return(response)

      expect { URLCanonicalize.fetch(url) }.to raise_error(URLCanonicalize::Exception::Failure)
    end

    it 'follows canonical url metadata' do
      url = 'http://twitter.com'
      canonical_url = 'https://twitter.com'
      html = "<html><head><link rel=\"canonical\" href=\"#{canonical_url}\" /></head></html>"

      http = URLCanonicalize::HTTP.new(url)
      response = Net::HTTPOK.new('1.1', '200', '')
      response['Content-Type'] = 'text/html; charset=utf-8'

      expect(URLCanonicalize::HTTP).to receive(:new).and_return(http)
      expect(response).to receive(:body).and_return(html, '', '')
      expect(http).to receive(:do_request).exactly(3).times.and_return(response)

      expect(URLCanonicalize.canonicalize(url)).to eq(canonical_url)
    end

    it 'finds the canonical link among multiple links in a Link header' do
      url = 'http://twitter.com'
      canonical_url = 'https://twitter.com/canonical'
      http = URLCanonicalize::HTTP.new(url)
      request = described_class.new(http)
      response = Net::HTTPOK.new('1.1', '200', '')
      response['Link'] = "<https://twitter.com/style.css>; rel=\"stylesheet\", <#{canonical_url}>; rel=\"canonical\""

      allow(request).to receive(:do_http_request).and_return(response)

      result = request.with_uri(URLCanonicalize::URI.parse(url)).fetch

      expect(result).to be_a(URLCanonicalize::Response::CanonicalFound)
      expect(result.url).to eq(canonical_url)
    end

    it 'resolves a relative canonical Link target against the request URL' do
      url = 'http://twitter.com'
      http = URLCanonicalize::HTTP.new(url)
      request = described_class.new(http)
      response = Net::HTTPOK.new('1.1', '200', '')
      response['Link'] = '</canonical>; rel=canonical'

      allow(request).to receive(:do_http_request).and_return(response)

      result = request.with_uri(URLCanonicalize::URI.parse(url)).fetch

      expect(result).to be_a(URLCanonicalize::Response::CanonicalFound)
      expect(result.url).to eq('http://twitter.com/canonical')
    end

    it 'does not leak canonical state to the next URI' do
      url = 'http://twitter.com'
      canonical_url = 'https://twitter.com/'
      html = "<html><head><link rel=\"canonical\" href=\"#{canonical_url}\" /></head></html>"

      http = URLCanonicalize::HTTP.new(url)
      request = described_class.new(http)

      with_canonical = Net::HTTPOK.new('1.1', '200', '')
      with_canonical['Content-Type'] = 'text/html'
      allow(with_canonical).to receive(:body).and_return(html)

      plain = Net::HTTPOK.new('1.1', '200', '')
      plain['Content-Type'] = 'text/html'
      allow(plain).to receive(:body).and_return('<html><head></head></html>')

      allow(request).to receive(:do_http_request).and_return(with_canonical, plain, plain)

      expect(request.with_uri(URLCanonicalize::URI.parse(url)).fetch)
        .to be_a(URLCanonicalize::Response::CanonicalFound)
      expect(request.with_uri(URLCanonicalize::URI.parse(canonical_url)).fetch)
        .to be_a(URLCanonicalize::Response::Success)
    end

    it 'resets the HTTP method for each new URI' do
      url = 'http://twitter.com'
      http = URLCanonicalize::HTTP.new(url)
      request = described_class.new(http)
      plain = Net::HTTPOK.new('1.1', '200', '')
      allow(plain).to receive(:body).and_return('')
      allow(request).to receive(:do_http_request).and_return(plain)

      request.with_uri(URLCanonicalize::URI.parse(url)).fetch
      expect(request.send(:http_method)).to eq(:get)

      request.with_uri(URLCanonicalize::URI.parse('https://twitter.com/'))
      expect(request.send(:http_method)).to eq(:head)
    end

    it 'recognizes HTML canonical links case-insensitively' do
      html = '<html><head><link rel="Canonical" href="https://twitter.com/x" /></head></html>'
      result = html_success_request(html).fetch

      expect(result).to be_a(URLCanonicalize::Response::CanonicalFound)
      expect(result.url).to eq('https://twitter.com/x')
    end

    it 'recognizes canonical among multiple rel tokens' do
      html = '<html><head><link rel="canonical nofollow" href="https://twitter.com/x" /></head></html>'
      result = html_success_request(html).fetch

      expect(result).to be_a(URLCanonicalize::Response::CanonicalFound)
      expect(result.url).to eq('https://twitter.com/x')
    end

    it 'resolves an HTML canonical link against the document base URL' do
      html = '<html><head><base href="https://base.example/dir/">' \
             '<link rel="canonical" href="page"></head></html>'
      result = html_success_request(html).fetch

      expect(result).to be_a(URLCanonicalize::Response::CanonicalFound)
      expect(result.url).to eq('https://base.example/dir/page')
    end

    it 'ignores a canonical link without a usable href' do
      html = '<html><head><link rel="canonical" href=" " /></head></html>'

      expect(html_success_request(html).fetch).to be_a(URLCanonicalize::Response::Success)
    end

    def html_success_request(html, url: 'http://twitter.com')
      http = URLCanonicalize::HTTP.new(url)
      request = described_class.new(http)
      response = Net::HTTPOK.new('1.1', '200', '')
      response['Content-Type'] = 'text/html'
      allow(response).to receive(:body).and_return(html)
      allow(request).to receive(:do_http_request).and_return(response)
      request.with_uri(URLCanonicalize::URI.parse(url))
    end

    it 'does not parse non-HTML successful responses as HTML' do
      url = 'https://example.com/data'
      http = URLCanonicalize::HTTP.new(url)
      response = Net::HTTPOK.new('1.1', '200', '')
      response['Content-Type'] = 'application/xml'

      allow(response).to receive(:body).and_return('<root />')
      allow(http).to receive(:do_request).and_return(response)

      result = described_class.new(http).with_uri(URLCanonicalize::URI.parse(url)).fetch

      expect(result.html).to be_nil
    end
  end

  context 'HEAD fallback' do
    {
      '403' => Net::HTTPForbidden,
      '405' => Net::HTTPMethodNotAllowed,
      '501' => Net::HTTPNotImplemented
    }.each do |code, response_class|
      it "retries a HEAD request rejected with #{code} as a GET" do
        url = 'http://twitter.com'
        http = URLCanonicalize::HTTP.new(url)
        request = described_class.new(http)
        rejection = response_class.new('1.1', code, '')
        ok = Net::HTTPOK.new('1.1', '200', '')

        expect(request).to receive(:do_http_request).twice.and_return(rejection, ok)

        expect(request.with_uri(URLCanonicalize::URI.parse(url)).fetch)
          .to be_a(URLCanonicalize::Response::Success)
      end
    end

    it 'does not retry an unsuccessful GET request' do
      url = 'http://twitter.com'
      http = URLCanonicalize::HTTP.new(url)
      request = described_class.new(http)
      rejection = Net::HTTPMethodNotAllowed.new('1.1', '405', '')

      expect(request).to receive(:do_http_request).twice.and_return(rejection, rejection)

      expect(request.with_uri(URLCanonicalize::URI.parse(url)).fetch)
        .to be_a(URLCanonicalize::Response::Failure)
    end

    it 'uses HEAD first for every host' do
      url = 'https://www.linkedin.com/company/example'
      http = URLCanonicalize::HTTP.new(url)
      request = described_class.new(http).with_uri(URLCanonicalize::URI.parse(url))

      expect(request.send(:request).method).to eq('HEAD')
    end
  end

  context 'HTTP method' do
    it 'handles invalid HTTP methods' do
      http = URLCanonicalize::HTTP.new('http://twitter.com')
      request = described_class.new(http)
      request.send(:http_method=, 'nonsense')
      expect { request.send(:base_request) }.to raise_error(URLCanonicalize::Exception::Request, 'Unknown method: nonsense')
    end
  end

  context 'real world examples' do
    before do
      allow(Addrinfo).to receive(:getaddrinfo)
        .and_return([Addrinfo.tcp('93.184.216.34', 80)])
    end

    it 'preserves the original network error as the cause of the raised failure' do
      url = 'http://twitter.com'
      stub_request(:any, url).to_raise(SocketError.new('getaddrinfo: Name or service not known'))

      expect { URLCanonicalize.fetch(url) }.to raise_error(URLCanonicalize::Exception::Failure) do |exception|
        expect(exception.cause).to be_a(SocketError)
      end
    end

    # Recent versions of URI do not barf when asked to parse http://$$$, http://_ or http://~ so I've commented those out
    # examples
    [
      { url: 'http:',                       outcome: :exception_uri,          message: 'Missing host name in http:' },
      { url: 'http:/',                      outcome: :exception_uri,          message: 'Missing host name in http:/' },
      { url: 'http://',                     outcome: :exception_uri,          message: 'Empty host name in http://' },
      # { url: 'http://$$$',                  outcome: :exception_uri,          message: 'URI::InvalidURIError: the scheme http does not accept registry part: $$$ (or bad hostname?)' },
      { url: 'http://-',                    outcome: :exception_failure,      message: 'getaddrinfo: Name or service not known', klass: SocketError },
      { url: 'http://.',                    outcome: :exception_failure,      message: 'getaddrinfo: No address associated with hostname', klass: SocketError },
      { url: 'http://..',                   outcome: :exception_failure,      message: 'getaddrinfo: No address associated with hostnamex', klass: SocketError },
      { url: 'http://...',                  outcome: :exception_failure,      message: 'getaddrinfo: Name or service not known', klass: SocketError },
      { url: 'http:////',                   outcome: :exception_uri,          message: 'Empty host name in http:////' },
      { url: 'http://00-o.com',             outcome: :exception_failure,      message: 'execution expired',                                 klass: Net::OpenTimeout },
      { url: 'http://123deals.com',         outcome: :exception_failure,      message: 'connect(2) for "123deals.com" port 80',             klass: Errno::EHOSTUNREACH },
      { url: 'http://123people.com',        outcome: :exception_unsuccessful, message: 'Gone',                                              klass: Net::HTTPGone },
      { url: 'http://12gigs.com',           outcome: :exception_unsuccessful, message: 'Service Unavailable',                               klass: Net::HTTPServiceUnavailable },
      { url: 'http://195places.com',        outcome: :exception_failure,      message: 'Net::ReadTimeout',                                  klass: Net::ReadTimeout },
      { url: 'http://1drv.ms/1zkgpqd',      outcome: :exception_unsuccessful, message: 'Method Not Allowed',                                klass: Net::HTTPMethodNotAllowed },
      { url: 'http://2015.com/',            outcome: :exception_failure,      message: 'Connection reset by peer',                          klass: Errno::ECONNRESET },
      { url: 'http://29thdrive.com/',       outcome: :exception_unsuccessful, message: 'Method Not Allowed',                                klass: Net::HTTPMethodNotAllowed },
      { url: 'http://2lr.co',               outcome: :exception_failure,      message: 'connect(2) for "2lr.co" port 80',                   klass: Errno::ECONNREFUSED },
      { url: 'http://3',                    outcome: :exception_failure,      message: 'connect(2) for "3" port 80',                        klass: Errno::EINVAL },
      { url: 'http://30dayjetset.com',      outcome: :exception_unsuccessful, message: 'Forbidden',                                         klass: Net::HTTPForbidden },
      { url: 'http://3scape.me',            outcome: :exception_unsuccessful, message: 'Internal Server Error',                             klass: Net::HTTPInternalServerError },
      { url: 'http://46sports.com/',        outcome: :exception_unsuccessful, message: 'Bad Request',                                       klass: Net::HTTPBadRequest },
      { url: 'http://4bit.co',              outcome: :exception_unsuccessful, message: 'Not Found',                                         klass: Net::HTTPNotFound },
      { url: 'http://54.214.34.113/home/',  outcome: :exception_unsuccessful, message: 'Unauthorized',                                      klass: Net::HTTPUnauthorized },
      { url: 'http://5min.to/',             outcome: :exception_failure,      message: 'getaddrinfo: Name or service not known',            klass: SocketError },
      { url: 'http://60daymba.com',         outcome: :exception_failure,      message: 'getaddrinfo: No address associated with hostname',  klass: SocketError },
      # { url: 'http://_',                    outcome: :exception_uri,          message: 'URI::InvalidURIError: the scheme http does not accept registry part: _ (or bad hostname?)' },
      { url: 'http://www.twitter.com',      outcome: :success }
      # { url: 'http://~',                    outcome: :exception_uri, message: 'URI::InvalidURIError: the scheme http does not accept registry part: ~ (or bad hostname?)' }
    ].shuffle.each do |test|
      it 'handles real-world data' do
        url, outcome, message, klass = *test.values

        case outcome
        when :success
          stub_request(:any, url)
          expect(URLCanonicalize.fetch(url)).to be_a(URLCanonicalize::Response::Success)
        when :exception_uri
          expect_exception URLCanonicalize::Exception::URI, test
        when :exception_failure
          stub_request(:any, url).to_raise(test[:klass].new(message))
          expect_exception URLCanonicalize::Exception::Failure, test
        when :exception_unsuccessful
          stub_request(:any, url).to_return(status: [http_code_from(klass), message])
          expect_exception URLCanonicalize::Exception::Failure, test
        else
          expect(true).to be_false
        end
      end
    end

    def expect_exception(klass, test)
      expect { URLCanonicalize.fetch(test[:url]) }.to raise_error do |e|
        specific_expectations(e, klass, test)
      end
    end

    def specific_expectations(exception, klass, test)
      expect(exception).to be_a(klass)
      expect(exception.message).to include(test[:message])
      expect(exception.message).to include(test[:klass].name) if test.key?(:klass)
    end

    def http_code_from(klass)
      Net::HTTPResponse::CODE_TO_OBJ.select { |_, v| v == klass }.keys[0]
    end
  end
end
