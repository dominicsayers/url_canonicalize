describe URLCanonicalize::URI do
  let(:host) { 'www.twitter.com' }
  let(:protocol) { 'http' }
  let(:url) { "#{protocol}://#{host}" }

  it 'accepts a valid URL' do
    uri = URLCanonicalize::URI.parse(url)
    expect(uri).to be_a(URI::HTTP)
    expect(uri.scheme).to eq protocol
    expect(uri.host).to eq host
  end

  it 'raises an exception for an unexpected protocol' do
    expect do
      URLCanonicalize::URI.parse('mailto:developers@xenapto.com')
    end.to raise_error(
      URLCanonicalize::Exception::URI, 'mailto:developers@xenapto.com must be http or https'
    )
  end

  it 'raises an exception for an malformed URL' do
    expect do
      URLCanonicalize::URI.parse('http://#')
    end.to raise_error(
      URLCanonicalize::Exception::URI, 'URI::InvalidURIError: bad URI(absolute but no path): http://#'
    )
  end

  it 'raises an exception for a URL without a host' do
    expect do
      URLCanonicalize::URI.parse('http:///')
    end.to raise_error(
      URLCanonicalize::Exception::URI, 'Missing host name in http:/'
    )
  end
end
