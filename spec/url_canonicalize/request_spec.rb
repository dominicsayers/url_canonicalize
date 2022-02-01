# frozen_string_literal: true

describe URLCanonicalize::Request do
  context 'response types' do
    it 'follows temporary redirections' do
      responses = [
        Net::HTTPFound.new('1.1', '302', ''),
        Net::HTTPOK.new('1.1', '200', '')
      ]

      responses.each { |response| expect(response).to receive(:body).and_return('') }
      expect_any_instance_of(URLCanonicalize::Request).to receive(:do_http_request).and_return(*responses)
      URLCanonicalize.fetch('http://twitter.com')
    end

    it 'logs the response if required' do
      responses = [
        Net::HTTPOK.new('1.1', '200', ''),
        Net::HTTPOK.new('1.1', '200', '')
      ]

      ENV['DEBUG'] = 'true'
      responses.each { |response| expect(response).to receive(:body).and_return('') }
      expect_any_instance_of(URLCanonicalize::Request).to receive(:do_http_request).and_return(*responses)
      URLCanonicalize.fetch('https://twitter.com')
    end

    it 'follows permanent redirections' do
      url = 'http://twitter.com'
      canonical_url = 'https://twitter.com'

      http = URLCanonicalize::HTTP.new(url)
      response = Net::HTTPPermanentRedirect.new('1.1', '301', '')
      response['location'] = canonical_url
      canonical_response = Net::HTTPOK.new('1.1', '200', '')

      expect(canonical_response).to receive(:body).twice.and_return('')
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

      expect(canonical_response).to receive(:body).twice.and_return('')
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

      expect(URLCanonicalize::HTTP).to receive(:new).and_return(http)
      expect(response).to receive(:body).and_return(html, '')
      expect(http).to receive(:do_request).twice.and_return(response)

      expect(URLCanonicalize.canonicalize(url)).to eq(canonical_url)
    end
  end

  context 'HTTP method' do
    it 'handles invalid HTTP methods' do
      http = URLCanonicalize::HTTP.new('http://twitter.com')
      request = URLCanonicalize::Request.new(http)
      request.send(:http_method=, 'nonsense')
      expect { request.send(:base_request) }.to raise_error(URLCanonicalize::Exception::Request, 'Unknown method: nonsense')
    end
  end

  context 'real world examples' do
    # Recent versions of URI do not barf when asked to parse http://$$$, http://_ or http://~ so I've commented those out
    # examples
    [
      { url: 'http:',                       outcome: :exception_uri,          message: 'Missing host name in http:' },
      { url: 'http:/',                      outcome: :exception_uri,          message: 'Missing host name in http:/' },
      { url: 'http://',                     outcome: :exception_uri,          message: 'Missing host name in http:' },
      # { url: 'http://$$$',                  outcome: :exception_uri,          message: 'URI::InvalidURIError: the scheme http does not accept registry part: $$$ (or bad hostname?)' },
      { url: 'http://-',                    outcome: :exception_failure,      message: 'getaddrinfo: Name or service not known',            klass: SocketError },
      { url: 'http://.',                    outcome: :exception_failure,      message: 'getaddrinfo: No address associated with hostname',  klass: SocketError },
      { url: 'http://..',                   outcome: :exception_failure,      message: 'getaddrinfo: No address associated with hostnamex', klass: SocketError },
      { url: 'http://...',                  outcome: :exception_failure,      message: 'getaddrinfo: Name or service not known',            klass: SocketError },
      { url: 'http:////',                   outcome: :exception_uri,          message: 'Missing host name in http://' },
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
