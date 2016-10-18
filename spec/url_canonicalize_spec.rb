describe URLCanonicalize do
  let(:host) { 'www.twitter.com' }
  let(:protocol) { 'http' }
  let(:url) { "#{protocol}://#{host}" }

  let(:http_ok) do
    h = Net::HTTPOK.new('1.1', '200', 'OK')
    h.uri = ::URI.parse(url)
    h
  end

  before do
    fetch_double = double
    expect(URLCanonicalize::Request).to receive(:new).once.and_return(fetch_double)
    expect(fetch_double).to receive(:fetch).once.and_return(http_ok)
  end

  it 'returns a Net::HTTPOK' do
    expect(URLCanonicalize.fetch(url)).to be_a(Net::HTTPOK)
  end

  it 'canonicalizes a URL' do
    expect(URLCanonicalize.canonicalize(url)).to eq(url)
  end
end
