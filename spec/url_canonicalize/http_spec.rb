# frozen_string_literal: true

describe URLCanonicalize::HTTP do
  context 'handling responses' do
    let(:host) { 'www.twitter.com' }
    let(:protocol) { 'http' }
    let(:url) { "#{protocol}://#{host}" }
    let(:http) { described_class.new(url) }
    let(:fetch_double) { double }
    let(:response) { URLCanonicalize::Response::Success.new(url, '', '') }

    before do
      expect(URLCanonicalize::Request).to receive(:new).and_return(fetch_double)
      expect(fetch_double).to receive(:with_uri).at_least(:once).and_return(fetch_double)
    end

    it 'returns a Net::HTTPOK' do
      expect(fetch_double).to receive(:fetch).once.and_return(response)
      expect(http.fetch).to be_a(URLCanonicalize::Response::Success)
    end

    it 'handles an unexpected response' do
      expect(fetch_double).to receive(:fetch).once.and_return('a string')
      expect { http.fetch }.to raise_error(URLCanonicalize::Exception::Failure, 'Unhandled response type: String')
    end

    it 'fails on more than the maximum number of redirects' do
      responses = Array.new(11) { |i| URLCanonicalize::Response::Redirect.new("#{url}#{i}") }
      expect(fetch_double).to receive(:fetch).exactly(11).times.and_return(*responses)
      expect { http.fetch }.to raise_error(URLCanonicalize::Exception::Redirect, '11 redirects is too many')
    end

    it 'detects a redirect loop' do
      responses = ["#{url}/a", "#{url}/b", "#{url}/a"].map { |u| URLCanonicalize::Response::Redirect.new(u) }
      expect(fetch_double).to receive(:fetch).exactly(3).times.and_return(*responses)
      expect { http.fetch }.to raise_error(URLCanonicalize::Exception::Redirect, 'Redirect loop detected')
    end

    it 'detects a redirect straight back to the original URL' do
      expect(fetch_double).to receive(:fetch).once.and_return(URLCanonicalize::Response::Redirect.new(url))
      expect { http.fetch }.to raise_error(URLCanonicalize::Exception::Redirect, 'Redirect loop detected')
    end

    it 'handles a canonical URL different to the called URL' do
      responses = [URLCanonicalize::Response::CanonicalFound.new('http://new.url', response), response]
      expect(fetch_double).to receive(:fetch).twice.and_return(*responses)
      expect(http.fetch).to be_a(URLCanonicalize::Response::Success)
    end

    it 'terminates a canonical link cycle deterministically' do
      other_url = "#{url}/other"
      responses = [
        URLCanonicalize::Response::CanonicalFound.new(other_url, response),
        URLCanonicalize::Response::CanonicalFound.new(url, response)
      ]
      expect(fetch_double).to receive(:fetch).twice.and_return(*responses)
      expect(http.fetch).to be_a(URLCanonicalize::Response::Success)
    end

    it 'counts followed canonical links against the hop budget' do
      http = described_class.new(url, max_redirects: 2)
      responses = (1..3).map do |i|
        URLCanonicalize::Response::CanonicalFound.new("#{url}/#{i}", response)
      end
      expect(fetch_double).to receive(:fetch).exactly(3).times.and_return(*responses)
      expect(http.fetch).to be_a(URLCanonicalize::Response::Success)
    end

    it 'shares one hop budget between redirects and canonical links' do
      http = described_class.new(url, max_redirects: 2)
      responses = [
        URLCanonicalize::Response::Redirect.new("#{url}/1"),
        URLCanonicalize::Response::CanonicalFound.new("#{url}/2", response),
        URLCanonicalize::Response::Redirect.new("#{url}/3")
      ]
      expect(fetch_double).to receive(:fetch).exactly(3).times.and_return(*responses)
      expect(http.fetch).to be_a(URLCanonicalize::Response::Success)
    end
  end

  context 'handling protocols' do
    let(:resolved_address) { '93.184.216.34' }

    before do
      allow(URLCanonicalize::Destination).to receive(:resolve).and_return(resolved_address)
    end

    it 'uses SSL' do
      url = 'https://twitter.com'
      http = described_class.new(url).send(:http)

      expect(http).to be_use_ssl
      expect([http.verify_mode, http.verify_hostname, http.ipaddr]).to eq(
        [OpenSSL::SSL::VERIFY_PEER, true, resolved_address]
      )
      expect(http).not_to be_proxy_from_env
    end

    it 'uses HTTP' do
      url = 'http://twitter.com'
      http = described_class.new(url).send(:http)

      expect(http).not_to be_use_ssl
      expect(http.verify_mode).to be_nil
      expect(http.ipaddr).to eq(resolved_address)
      expect(http).not_to be_proxy_from_env
    end

    it 'configures HTTP operation timeouts' do
      http = described_class.new(
        'https://twitter.com',
        open_timeout: 1,
        read_timeout: 2,
        write_timeout: 3
      ).send(:http)

      expect(http.open_timeout).to eq(1)
      expect(http.read_timeout).to eq(2)
      expect(http.write_timeout).to eq(3)
    end

    it 'pins each new host to its validated address' do
      operation = described_class.new('https://example.com')
      first_http = operation.send(:http)
      allow(URLCanonicalize::Destination).to receive(:resolve).and_return('8.8.8.8')

      operation.url = 'https://example.org'
      second_http = operation.send(:http)

      expect(first_http.ipaddr).to eq(resolved_address)
      expect(second_http.ipaddr).to eq('8.8.8.8')
    end

    it 'creates a new client when the scheme changes on the same port' do
      operation = described_class.new('http://example.com:443')
      first_http = operation.send(:http)

      operation.url = 'https://example.com:443'
      second_http = operation.send(:http)

      expect(second_http).not_to equal(first_http)
      expect([first_http.use_ssl?, second_http.use_ssl?]).to eq([false, true])
    end

    it 'rejects userinfo before reusing a client for the same origin' do
      operation = described_class.new('https://example.com')
      operation.send(:http)

      operation.url = 'https://user:secret@example.com/private'

      expect { operation.send(:http) }.to raise_error(
        URLCanonicalize::Exception::Security,
        'URLs containing userinfo are not allowed'
      )
    end
  end

  context 'when streaming response bodies' do
    let(:operation) { described_class.new('https://example.com', max_body_bytes: 5) }
    let(:client) { operation.send(:http) }

    before do
      allow(URLCanonicalize::Destination).to receive(:resolve).and_return('93.184.216.34')
    end

    it 'rejects an oversized Content-Length before reading the body' do
      request = Net::HTTP::Get.new('https://example.com')
      response = response_with(content_type: 'text/html', content_length: 6)
      allow(response).to receive(:read_body) { raise IOError, 'body should not be read' }
      stub_response(client, request, response)

      expect { operation.do_request(request) }.to raise_error(
        URLCanonicalize::Exception::ResponseTooLarge,
        'Response body exceeds 5 bytes'
      )
    end

    it 'rejects a chunk that crosses the byte limit' do
      request = Net::HTTP::Get.new('https://example.com')
      response = response_with(content_type: 'text/html')
      buffered_body = stub_response(client, request, response, chunks: %w[1234 56])

      expect { operation.do_request(request) }.to raise_error(URLCanonicalize::Exception::ResponseTooLarge)
      expect(buffered_body.call).to eq('1234')
    end

    [
      'text/html',
      'Text/HTML; Charset=UTF-8',
      'application/xhtml+xml',
      'application/xml',
      'text/xml'
    ].each do |content_type|
      it "buffers #{content_type}" do
        request = Net::HTTP::Get.new('https://example.com')
        response = response_with(content_type:)
        buffered_body = stub_response(client, request, response, chunks: %w[12 345])

        operation.do_request(request)

        expect(buffered_body.call).to eq('12345')
      end
    end

    it 'discards unsupported media types without buffering them' do
      request = Net::HTTP::Get.new('https://example.com')
      response = response_with(content_type: 'application/octet-stream')
      buffered_body = stub_response(client, request, response, chunks: ['123456'])

      operation.do_request(request)

      expect(buffered_body.call).to be_nil
    end

    it 'does not buffer HEAD response bodies' do
      request = Net::HTTP::Head.new('https://example.com')
      response = response_with(content_type: 'text/html')
      buffered_body = stub_response(client, request, response, chunks: ['123456'])

      operation.do_request(request)

      expect(buffered_body.call).to be_nil
    end

    it 'does not buffer redirect response bodies' do
      request = Net::HTTP::Get.new('https://example.com')
      response = response_with(response_class: Net::HTTPMovedPermanently, content_type: 'text/html')
      buffered_body = stub_response(client, request, response, chunks: ['123456'])

      operation.do_request(request)

      expect(buffered_body.call).to be_nil
    end
  end

  context 'when enforcing the total deadline' do
    let(:url) { 'https://example.com' }
    let(:request) { instance_double(URLCanonicalize::Request) }

    before do
      allow(URLCanonicalize::Request).to receive(:new).and_return(request)
      allow(request).to receive(:with_uri).and_return(request)
    end

    it 'raises a specific timeout error when the operation exceeds its deadline' do
      allow(request).to receive(:fetch) { sleep 0.05 }

      expect { described_class.new(url, total_timeout: 0.01).fetch }.to raise_error(
        URLCanonicalize::Exception::Timeout,
        'Canonicalization exceeded 0.01 seconds'
      )
    end

    it 'uses one deadline across multiple hops' do
      timeout_calls = 0
      responses = [
        URLCanonicalize::Response::Redirect.new("#{url}/redirect"),
        URLCanonicalize::Response::Success.new("#{url}/final", '', '')
      ]
      allow(request).to receive(:fetch).and_return(*responses)
      allow(Timeout).to receive(:timeout) do |*_arguments, &operation|
        timeout_calls += 1
        operation.call
      end

      expect(described_class.new(url, total_timeout: 0.05).fetch)
        .to be_a(URLCanonicalize::Response::Success)
      expect(timeout_calls).to eq(1)
    end
  end

  def response_with(content_type:, response_class: Net::HTTPOK, content_length: nil)
    code = Net::HTTPResponse::CODE_TO_OBJ.key(response_class)
    response = response_class.new('1.1', code, '')
    response['Content-Type'] = content_type
    response['Content-Length'] = content_length.to_s if content_length
    response
  end

  def stub_response(client, request, response, chunks: [])
    buffered_body = nil
    allow(response).to receive(:read_body) do |destination = nil, &block|
      buffered_body = destination
      chunks.each { |chunk| destination ? destination << chunk : block.call(chunk) }
    end
    allow(client).to receive(:request).with(request).and_yield(response).and_return(response)

    -> { buffered_body }
  end
end
