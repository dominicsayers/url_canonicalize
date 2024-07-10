# frozen_string_literal: true

describe URLCanonicalize::URI do
  let(:host) { 'www.twitter.com' }
  let(:protocol) { 'http' }
  let(:url) { "#{protocol}://#{host}" }

  it 'accepts a valid URL' do
    uri = described_class.parse(url)
    expect(uri).to be_a(URI::HTTP)
    expect(uri.scheme).to eq protocol
    expect(uri.host).to eq host
  end

  it 'raises an exception for an unexpected protocol' do
    expect do
      described_class.parse('mailto:developers@xenapto.com')
    end.to raise_error(
      URLCanonicalize::Exception::URI, 'mailto:developers@xenapto.com must be http or https'
    )
  end

  it 'raises an exception for an malformed URL' do
    expect do
      described_class.parse('http://#')
    end.to raise_error(
      URLCanonicalize::Exception::URI, 'Empty host name in http://#'
    )
  end

  it 'raises an exception for a URL without a host' do
    expect do
      described_class.parse('http:///')
    end.to raise_error(
      URLCanonicalize::Exception::URI, 'Empty host name in http:///'
    )
  end

  it 'raises an exception for a URL that ::URI raises an exception for' do
    expect do
      described_class.parse("http://\xFF")
    end.to raise_error(
      URLCanonicalize::Exception::URI, 'URI::InvalidURIError: URI must be ascii only "http://\xFF"'
    )
  end
end
