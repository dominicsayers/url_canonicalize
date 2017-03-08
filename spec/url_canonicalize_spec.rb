describe URLCanonicalize do
  let(:host) { 'www.twitter.com' }
  let(:protocol) { 'http' }
  let(:url) { "#{protocol}://#{host}" }
  let(:response) { URLCanonicalize::Response::Success.new(url, '', '') }

  before do
    fetch_double = double
    expect(URLCanonicalize::Request).to receive(:new).once.and_return(fetch_double)
    expect(fetch_double).to receive(:fetch).and_return(response)
    expect(fetch_double).to receive(:with_uri).and_return(fetch_double)
  end

  it 'returns a Net::HTTPOK' do
    expect(URLCanonicalize.fetch(url)).to be_a(URLCanonicalize::Response::Success)
  end

  it 'canonicalizes a URL' do
    expect(URLCanonicalize.canonicalize(url)).to eq(url)
  end
end
