# frozen_string_literal: true

describe String do
  let(:host) { 'www.twitter.com' }
  let(:protocol) { 'http' }
  let(:url) { "#{protocol}://#{host}" }

  before { allow(URLCanonicalize).to receive(:canonicalize).at_least(:once).and_return(url) }

  it 'responds to the canonicalize method' do
    expect(url).to respond_to(:canonicalize)
  end

  it 'is the expected class' do
    expect(url.canonicalize).to be_a(described_class)
  end

  it 'forwards security options' do
    allow(URLCanonicalize).to receive(:canonicalize).and_call_original

    expect { url.canonicalize(unknown: true) }
      .to raise_error(ArgumentError, 'Unknown options: unknown')
  end
end
