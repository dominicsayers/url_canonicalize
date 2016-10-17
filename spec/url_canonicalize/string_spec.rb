describe String do
  let(:host) { 'www.twitter.com' }
  let(:protocol) { 'http' }
  let(:url) { "#{protocol}://#{host}" }

  it 'responds to the canonicalize method' do
    expect(url).to respond_to(:canonicalize)
  end

  it 'is the expected class' do
    expect(url.canonicalize).to be_a(String)
  end
end
