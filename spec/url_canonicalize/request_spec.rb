describe URLCanonicalize::Request do
  [
    { url: 'http:', outcome: :exception_uri, message: 'URI::InvalidURIError: bad URI(absolute but no path): http:' },
    { url: 'http:/', outcome: :exception_uri, message: 'Missing host name in http:/' },
    { url: 'http://~', outcome: :exception_uri, message: 'URI::InvalidURIError: the scheme http does not accept registry part: ~ (or bad hostname?)' },
    { url: 'http://_', outcome: :exception_uri, message: 'URI::InvalidURIError: the scheme http does not accept registry part: _ (or bad hostname?)' },
    { url: 'http://-', outcome: :exception_failure, klass: SocketError, message: 'getaddrinfo: Name or service not known' },
    { url: 'http:////', outcome: :exception_uri, message: 'Net::OpenTimeout: execution expired' },
    { url: 'http://.', outcome: :exception_failure, klass: SocketError, message: 'getaddrinfo: No address associated with hostname' },
    { url: 'http://..', outcome: :exception_failure, klass: SocketError, message: 'getaddrinfo: No address associated with hostname'  },
    { url: 'http://...', outcome: :exception_failure, klass: SocketError, message: 'getaddrinfo: Name or service not known' },
    { url: 'http://$$$', outcome: :exception_uri, message: 'URI::InvalidURIError: the scheme http does not accept registry part: $$$ (or bad hostname?)' },
    { url: 'http://00-o.com', outcome: :exception_failure, klass: Net::OpenTimeout, message: 'execution expired' },
    { url: 'http://123deals.com', outcome: :exception_failure, klass: Errno::EHOSTUNREACH, message: 'connect(2) for "123deals.com" port 80' },
    { url: 'http://123people.com', outcome: :exception_failure, klass: Net::HTTPGone, message: 'Gone' },
    { url: 'http://12gigs.com', outcome: :exception_failure, klass: Net::HTTPServiceUnavailable, message: 'Service Unavailable' },
    { url: 'http://195places.com', outcome: :exception_failure, klass: Net::ReadTimeout, message: 'Net::ReadTimeout' },
    { url: 'http://1drv.ms/1zkgpqd', outcome: :exception_failure, klass: Net::HTTPMethodNotAllowed, message: 'Method Not Allowed' },
    { url: 'http://2015.com/', outcome: :exception_failure, klass: Errno::ECONNRESET, message: 'Connection reset by peer' },
    { url: 'http://29thdrive.com/', outcome: :exception_failure, klass: Net::HTTPMethodNotAllowed, message: 'Method Not Allowed' },
    { url: 'http://2lr.co', outcome: :exception_failure, klass: Errno::ECONNREFUSED, message: 'connect(2) for "2lr.co" port 80' },
    { url: 'http://3', outcome: :exception_failure, klass: Errno::EINVAL, message: 'connect(2) for "3" port 80' },
    { url: 'http://30dayjetset.com', outcome: :exception_failure, klass: Net::HTTPForbidden, message: 'Forbidden' },
    { url: 'http://3scape.me', outcome: :exception_failure, klass: Net::HTTPInternalServerError, message: 'Internal Server Error' },
    { url: 'http://46sports.com/', outcome: :exception_failure, klass: Net::HTTPBadRequest, message: 'Bad Request' },
    { url: 'http://4bit.co', outcome: :exception_failure, klass: Net::HTTPNotFound, message: 'Not Found' },
    { url: 'http://54.214.34.113/home/', outcome: :exception_failure, klass: Net::HTTPUnauthorized, message: 'Unauthorized' },
    { url: 'http://5min.to/', outcome: :exception_failure, klass: SocketError, message: 'getaddrinfo: Name or service not known' },
    { url: 'http://60daymba.com', outcome: :exception_failure, klass: SocketError, message: 'getaddrinfo: No address associated with hostname' },
    { url: 'http://www.twitter.com', outcome: :success, canonical_url: 'https://twitter.com/' }
  ].shuffle.each do |test|
    it 'handles real-world data' do
      puts test.to_s.cyan if ENV['DEBUG']

      case test[:outcome]
      when :success
        stub_request(:any, host_from(test)).to_return(make_response_from(test))

        response = URLCanonicalize.fetch(test[:url])
        puts response.uri.inspect # debug
        expect(response).to be_a(Net::HTTPSuccess)
        expect(response.uri.to_s).to eq(test[:canonical_url] || test[:url])
      when :exception_uri
        expect { URLCanonicalize.fetch(test[:url]) }.to raise_error do |e|
          expect(e).to be_a(URLCanonicalize::Exception::URI)
          expect(e.message).to eq("#{test[:klass]}: #{test[:message]}") if test.key?(:klass)
        end
      when :exception_failure
        puts test[:klass].name.magenta # debug
        exception = make_response_from(test)
        puts exception # debug

        host = host_from(test)
        puts host # debug

        stub_request(:any, host).to_raise(exception)

        expect { URLCanonicalize.fetch(test[:url]) }.to raise_error do |e|
          expect(e).to be_a(URLCanonicalize::Exception::Failure)
          expect(e.message).to include(test[:klass].name, test[:message]) if test.key?(:klass)
        end
      else
        expect(true).to be_false
      end
    end
  end

  def make_response_from(test)
    klass = test[:klass]

    if klass.nil?
      r = Net::HTTPOK.new('1.1', '200', 'OK')
      r.uri = ::URI.parse(test[:canonical_url] || test[:url])
      r
    elsif [SystemCallError, StandardError].include?(klass.superclass) # Errno or SocketError
      klass.new(test[:message])
    else
      klass.new('1.1', http_code_from(klass), test[:message])
    end
  end

  def http_code_from(klass)
    Net::HTTPResponse::CODE_TO_OBJ.select { |_, v| v == klass }.keys[0]
  end

  def host_from(test)
    uri = ::URI.parse(test[:url])
    uri.host
  end
end
