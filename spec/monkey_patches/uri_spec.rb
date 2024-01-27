# frozen_string_literal: true

describe URI do
  let(:host) { 'www.twitter.com' }
  let(:protocol) { 'http' }
  let(:url) { "#{protocol}://#{host}" }

  before { allow(URLCanonicalize).to receive(:canonicalize).at_least(:once).and_return(url) }

  it 'responds to the canonicalize method' do
    expect(URI.parse(url)).to respond_to(:canonicalize)
    expect(URI::HTTP.build(host: host)).to respond_to(:canonicalize)
    expect(URI::HTTPS.build(host: host)).to respond_to(:canonicalize)
  end

  it 'is the expected class' do
    expect(URI.parse(url).canonicalize).to be_a(URI::HTTP)
  end
end
