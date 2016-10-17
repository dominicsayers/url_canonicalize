describe URI do
  let(:host) { 'www.twitter.com' }
  let(:protocol) { 'http' }
  let(:url) { "#{protocol}://#{host}" }

  it 'responds to the canonicalize method' do
    expect(URI(url)).to respond_to(:canonicalize)
    expect(URI::HTTP.build(host: host)).to respond_to(:canonicalize)
    expect(URI::HTTPS.build(host: host)).to respond_to(:canonicalize)
  end

  it 'is the expected class' do
    expect(URI(url).canonicalize).to be_a(URI::HTTP)
  end
end
