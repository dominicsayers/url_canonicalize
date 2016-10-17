describe Addressable::URI do
  let(:host) { 'www.twitter.com' }
  let(:protocol) { 'http' }
  let(:url) { "#{protocol}://#{host}" }

  before { allow(URLCanonicalize).to receive(:canonicalize).at_least(:once).and_return(url) }

  it 'responds to the canonicalize method' do
    expect(Addressable::URI).to respond_to(:canonicalize)
  end

  it 'is the expected class' do
    expect(Addressable::URI.canonicalize(url)).to be_a(Addressable::URI)
  end
end
