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
      URLCanonicalize::Exception::URI,
      "Addressable::URI::InvalidURIError: Absolute URI missing hierarchical segment: 'http://#'"
    )
  end

  it 'raises an exception for a URL without a host' do
    expect do
      described_class.parse('http:///')
    end.to raise_error(
      URLCanonicalize::Exception::URI, 'Empty host name in http:///'
    )
  end

  it 'raises an exception for a URL with invalid bytes' do
    expect do
      described_class.parse("http://\xFF")
    end.to raise_error(
      URLCanonicalize::Exception::URI, 'Encoding::CompatibilityError: invalid byte sequence in UTF-8'
    )
  end

  # Addressable and Ruby's URI parser can disagree between versions, so a
  # normalized URL that URI still rejects must surface as a URI exception
  it 'reports a normalized URL that URI cannot parse' do
    allow(described_class).to receive(:normalize).and_return('http://exa mple.com/')

    expect { described_class.parse('http://example.com/') }
      .to raise_error(URLCanonicalize::Exception::URI, /URI::InvalidURIError/)
  end

  it 'preserves the original parsing error as the cause' do
    expect { described_class.parse("http://\xFF") }.to raise_error(URLCanonicalize::Exception::URI) do |exception|
      expect(exception.cause).to be_a(Encoding::CompatibilityError)
    end
  end

  describe '.normalize' do
    {
      'scheme and host casing' => ['HTTP://ExAmPlE.CoM/Path', 'http://example.com/Path'],
      'a default HTTP port' => ['http://example.com:80/', 'http://example.com/'],
      'a default HTTPS port' => ['https://example.com:443/', 'https://example.com/'],
      'a non-default port (preserved)' => ['http://example.com:8080/', 'http://example.com:8080/'],
      'dot segments' => ['http://example.com/a/./b/../c', 'http://example.com/a/c'],
      'percent-encoded unreserved characters' => ['http://example.com/%7Euser/%41', 'http://example.com/~user/A'],
      'a fragment (stripped)' => ['http://example.com/page#section', 'http://example.com/page'],
      'an internationalized host' => ['http://exämple.com/', 'http://xn--exmple-cua.com/'],
      'a query string (preserved verbatim)' => ['http://example.com/?b=2&a=1', 'http://example.com/?b=2&a=1'],
      'a trailing slash (preserved)' => ['http://example.com/a/', 'http://example.com/a/'],
      'an empty path' => ['http://example.com', 'http://example.com/'],
      'surrounding whitespace' => [' http://example.com/ ', 'http://example.com/'],
      'a bare host name' => ['example.com', 'http://example.com/'],
      'an unencoded space' => ['http://example.com/a b', 'http://example.com/a%20b'],
      'a colon after the first path segment' => ['example.com/tag:ruby', 'http://example.com/tag:ruby']
    }.each do |label, (input, expected)|
      it "normalizes #{label}" do
        expect(described_class.normalize(input)).to eq(expected)
      end
    end
  end
end
