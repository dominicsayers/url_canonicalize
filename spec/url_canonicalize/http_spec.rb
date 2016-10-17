describe URLCanonicalize::HTTP do
  let(:host) { 'www.twitter.com' }
  let(:protocol) { 'http' }
  let(:url) { "#{protocol}://#{host}" }

  it 'returns a Net::HTTPOK' do
    http = URLCanonicalize::HTTP.new(url)
    expect(http).to receive(:response).twice.and_return(Net::HTTPOK.new(url, '/', 80))
    expect(http.fetch).to be_a(Net::HTTPOK)
  end

  it 'fails on more than the maximum number of redirects' do
    http = URLCanonicalize::HTTP.new(url)
    expect(http).to receive(:response).at_least(2).times.and_return(Net::HTTPNotFound.new(url, '/', 80))
    expect { http.fetch }.to raise_error(URLCanonicalize::Exception::Redirect, '11 redirects is too many')
  end
end
