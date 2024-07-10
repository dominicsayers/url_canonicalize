# frozen_string_literal: true

describe URLCanonicalize::Response::Redirect do
  let(:host) { 'www.twitter.com' }
  let(:protocol) { 'http' }
  let(:url) { "#{protocol}://#{host}" }

  describe URLCanonicalize::Response::Redirect do
    it 'has the expected properties' do
      response = described_class.new(url)
      expect(response.url).to eq(url)
    end
  end

  describe URLCanonicalize::Response::Success do
    it 'has the expected properties' do
      response = described_class.new(url, 'response', 'html')
      expect(response.url).to eq(url)
      expect(response.response).to eq('response')
      expect(response.html).to eq('html')
    end

    it 'can respond with xml' do
      response = described_class.new(url, Struct.new(:body).new('foo'), 'html')
      expect(response.xml).to be_a(Nokogiri::XML::Document)
    end
  end

  describe URLCanonicalize::Response::CanonicalFound do
    it 'has the expected properties' do
      response = described_class.new(url, 'response')
      expect(response.url).to eq(url)
      expect(response.response).to eq('response')
    end
  end

  describe URLCanonicalize::Response::Failure do
    it 'has the expected properties' do
      response = described_class.new('failure_class', 'message')
      expect(response.failure_class).to eq('failure_class')
      expect(response.message).to eq('message')
    end
  end
end
