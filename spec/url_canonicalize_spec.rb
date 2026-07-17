# frozen_string_literal: true

describe URLCanonicalize do
  context 'when delegating through the public API' do
    let(:host) { 'www.twitter.com' }
    let(:protocol) { 'https' }
    let(:url) { "#{protocol}://#{host}" }
    let(:response) { URLCanonicalize::Response::Success.new(url, '', '') }

    before do
      fetch_double = instance_double(URLCanonicalize::Request)
      allow(URLCanonicalize::Request).to receive(:new).and_return(fetch_double)
      allow(fetch_double).to receive_messages(fetch: response, with_uri: fetch_double)
    end

    it 'returns successfully for a complete URL' do
      expect(described_class.fetch(url)).to be_a(URLCanonicalize::Response::Success)
    end

    it 'returns successfully for a host name' do
      expect(described_class.fetch(host)).to be_a(URLCanonicalize::Response::Success)
    end

    it 'canonicalizes a URL' do
      expect(url.canonicalize).to eq(url)
    end
  end

  context 'when fetching a complete URL chain' do
    let(:public_address) { '93.184.216.34' }

    it 'blocks a prohibited initial destination' do
      stub_dns('blocked.test' => '127.0.0.1')

      expect { described_class.fetch('http://blocked.test') }.to raise_error(
        URLCanonicalize::Exception::Security,
        /127\.0\.0\.1/
      )
    end

    it 'blocks a prohibited redirect destination' do
      initial_url = 'http://public.test/start'
      blocked_url = 'http://blocked.test/secret'
      stub_dns('public.test' => public_address, 'blocked.test' => '169.254.169.254')
      stub_request(:head, initial_url).to_return(status: 301, headers: { 'Location' => blocked_url })

      expect { described_class.fetch(initial_url) }.to raise_error(
        URLCanonicalize::Exception::Security,
        /169\.254\.169\.254/
      )
    end

    it 'blocks a prohibited HTML canonical destination' do
      initial_url = 'http://public.test/article'
      blocked_url = 'http://blocked.test/canonical'
      html = %(<html><head><link rel="canonical" href="#{blocked_url}"></head></html>)
      stub_dns('public.test' => public_address, 'blocked.test' => '10.0.0.1')
      stub_request(:head, initial_url).to_return(status: 200)
      stub_request(:get, initial_url).to_return(
        status: 200,
        headers: { 'Content-Type' => 'text/html' },
        body: html
      )

      expect { described_class.fetch(initial_url) }.to raise_error(
        URLCanonicalize::Exception::Security,
        /10\.0\.0\.1/
      )
    end

    it 'blocks userinfo on a redirect within the same origin' do
      initial_url = 'http://public.test/start'
      blocked_url = 'http://user:secret@public.test/private'
      stub_dns('public.test' => public_address)
      stub_request(:head, initial_url).to_return(status: 301, headers: { 'Location' => blocked_url })

      expect { described_class.fetch(initial_url) }.to raise_error(
        URLCanonicalize::Exception::Security,
        'URLs containing userinfo are not allowed'
      )
    end

    it 'allows a private destination only when explicitly enabled' do
      url = 'http://private.test'
      stub_dns('private.test' => '127.0.0.1')
      stub_request(:head, url).to_return(status: 200)
      stub_request(:get, url).to_return(status: 200)

      expect(described_class.fetch(url, allow_private_networks: true))
        .to be_a(URLCanonicalize::Response::Success)
    end

    it 'keeps using the pinned address for later paths on the same origin' do
      initial_url = 'http://public.test/start'
      final_url = 'http://public.test/final'
      resolutions = 0
      allow(Addrinfo).to receive(:getaddrinfo) do |_host, port, *_arguments|
        resolutions += 1
        address = resolutions == 1 ? public_address : '127.0.0.1'
        [Addrinfo.tcp(address, port)]
      end
      stub_request(:head, initial_url).to_return(status: 301, headers: { 'Location' => final_url })
      stub_request(:head, final_url).to_return(status: 200)
      stub_request(:get, final_url).to_return(status: 200)

      expect(described_class.fetch(initial_url)).to be_a(URLCanonicalize::Response::Success)
      expect(resolutions).to eq(1)
    end

    it 'surfaces TLS verification failures as fetch failures' do
      url = 'https://public.test'
      stub_dns('public.test' => public_address)
      stub_request(:head, url).to_raise(OpenSSL::SSL::SSLError.new('certificate verify failed'))

      expect { described_class.fetch(url) }.to raise_error(
        URLCanonicalize::Exception::Failure,
        /certificate verify failed/
      )
    end
  end

  context 'when following redirects and canonical links at the HTTP boundary' do
    let(:public_address) { '93.184.216.34' }

    before do
      allow(Addrinfo).to receive(:getaddrinfo) do |_host, port, *_arguments|
        [Addrinfo.tcp(public_address, port)]
      end
    end

    it 'follows a chain of redirects, resolving each Location form' do
      stub_request(:head, 'http://start.test/')
        .to_return(status: 301, headers: { 'Location' => 'https://middle.test/a' })
      stub_request(:head, 'https://middle.test/a')
        .to_return(status: 302, headers: { 'Location' => '//final.test/b' })
      stub_request(:head, 'https://final.test/b').to_return(status: 200)
      stub_request(:get, 'https://final.test/b').to_return(status: 200)

      expect(described_class.canonicalize('http://start.test')).to eq('https://final.test/b')
    end

    it 'follows a canonical Link header and falls back to the last known good response when its target fails' do
      stub_request(:head, 'https://site.test/page')
        .to_return(status: 200, headers: { 'Link' => '</canonical>; rel=canonical' })
      stub_request(:head, 'https://site.test/canonical').to_raise(SocketError)

      expect(described_class.canonicalize('https://site.test/page')).to eq('https://site.test/canonical')
    end

    it 'discovers a canonical link in the HTML head and resolves it against the document base URL' do
      html = '<html><head><base href="https://cdn.test/dir/"><link rel="Canonical" href="page"></head></html>'
      stub_request(:head, 'https://site.test/article').to_return(status: 200)
      stub_request(:get, 'https://site.test/article')
        .to_return(status: 200, body: html, headers: { 'Content-Type' => 'text/html' })
      stub_request(:head, 'https://cdn.test/dir/page').to_return(status: 200)
      stub_request(:get, 'https://cdn.test/dir/page').to_return(status: 200)

      expect(described_class.canonicalize('https://site.test/article')).to eq('https://cdn.test/dir/page')
    end

    it 'raises when redirects form a loop' do
      stub_request(:head, 'https://loop.test/a').to_return(status: 302, headers: { 'Location' => '/b' })
      stub_request(:head, 'https://loop.test/b').to_return(status: 302, headers: { 'Location' => '/a' })

      expect { described_class.fetch('https://loop.test/a') }
        .to raise_error(URLCanonicalize::Exception::Redirect, 'Redirect loop detected')
    end

    it 'raises when the hop budget is exhausted' do
      stub_request(:head, 'https://deep.test/1').to_return(status: 301, headers: { 'Location' => '/2' })
      stub_request(:head, 'https://deep.test/2').to_return(status: 301, headers: { 'Location' => '/3' })

      expect { described_class.fetch('https://deep.test/1', max_redirects: 1) }
        .to raise_error(URLCanonicalize::Exception::Redirect, '2 redirects is too many')
    end

    it 'retries a rejected HEAD request as a GET' do
      stub_request(:head, 'https://nohead.test/').to_return(status: 405)
      stub_request(:get, 'https://nohead.test/').to_return(status: 200)

      expect(described_class.fetch('https://nohead.test')).to be_a(URLCanonicalize::Response::Success)
    end

    it 'rejects a response body that exceeds the size limit' do
      stub_request(:head, 'https://big.test/').to_return(status: 200)
      stub_request(:get, 'https://big.test/')
        .to_return(status: 200, body: 'x' * 10, headers: { 'Content-Type' => 'text/html' })

      expect { described_class.fetch('https://big.test', max_body_bytes: 5) }
        .to raise_error(URLCanonicalize::Exception::ResponseTooLarge)
    end
  end

  def stub_dns(hosts)
    allow(Addrinfo).to receive(:getaddrinfo) do |host, port, *_arguments|
      [Addrinfo.tcp(hosts.fetch(host), port)]
    end
  end
end
