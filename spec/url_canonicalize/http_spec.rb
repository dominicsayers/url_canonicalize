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
      responses = [url, "#{url}xxx", url].map { |u| URLCanonicalize::Response::Redirect.new(u) }
      expect(fetch_double).to receive(:fetch).exactly(3).times.and_return(*responses)
      expect { http.fetch }.to raise_error(URLCanonicalize::Exception::Redirect, 'Redirect loop detected')
    end

    it 'handles a canonical URL different to the called URL' do
      responses = [URLCanonicalize::Response::CanonicalFound.new('http://new.url', response), response]
      expect(fetch_double).to receive(:fetch).twice.and_return(*responses)
      expect(http.fetch).to be_a(URLCanonicalize::Response::Success)
    end
  end

  context 'handling protocols' do
    it 'uses SSL' do
      url = 'https://twitter.com'
      http = described_class.new(url).send(:http)
      expect(http).to be_use_ssl
      expect(http.verify_mode).to eq(OpenSSL::SSL::VERIFY_NONE)
    end

    it 'uses HTTP' do
      url = 'http://twitter.com'
      http = described_class.new(url).send(:http)
      expect(http).not_to be_use_ssl
      expect(http.verify_mode).to be_nil
    end
  end
end
