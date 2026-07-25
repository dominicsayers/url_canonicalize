# frozen_string_literal: true

describe URLCanonicalize::Client do
  let(:url) { 'http://example.test/' }

  def stubbed_connection(response)
    connection = instance_double(Net::HTTP)
    allow(connection).to receive(:request) do |_request, &block|
      block&.call(response)
      response
    end
    connection
  end

  def success_response(body: nil)
    response = Net::HTTPOK.new('1.1', '200', 'OK')
    allow(response).to receive(:read_body)
    allow(response).to receive(:body).and_return(body) if body
    response
  end

  it 'fetches through an injected transport without touching the network' do
    transport_calls = []
    connection = stubbed_connection(success_response)
    transport = lambda do |uri, options|
      transport_calls << [uri.host, options[:open_timeout]]
      connection
    end

    result = described_class.new(transport: transport, open_timeout: 3).fetch(url)

    expect([result.url, result.source, transport_calls.first]).to eq([url, :initial, ['example.test', 3]])
  end

  it 'returns the canonical URL as a string' do
    transport = ->(_uri, _options) { stubbed_connection(success_response) }

    expect(described_class.new(transport: transport).canonicalize(url)).to eq(url)
  end

  it 'sends the configured request headers' do
    seen_headers = []
    response = success_response
    connection = instance_double(Net::HTTP)
    allow(connection).to receive(:request) do |request, &block|
      seen_headers << request['X-Purpose']
      block&.call(response)
      response
    end

    described_class.new(transport: ->(_uri, _options) { connection }, headers: { 'X-Purpose' => 'testing' })
                   .fetch(url)

    expect(seen_headers).to all(eq('testing'))
  end

  it 'validates its options once at construction' do
    expect { described_class.new(unknown: true) }.to raise_error(ArgumentError, 'Unknown options: unknown')
  end

  it 'freezes its options so one client can be shared safely' do
    expect(described_class.new.options).to be_frozen
  end

  it 'exposes the request chain and the parsed body on the result' do
    response = success_response(body: '<data/>')
    response['Content-Type'] = 'text/xml'
    transport = ->(_uri, _options) { stubbed_connection(response) }

    result = described_class.new(transport: transport).fetch(url)

    expect([result.chain.map(&:url), result.chain.map(&:via), result.xml])
      .to match([[url], [:initial], be_a(Nokogiri::XML::Document)])
  end

  it 'rejects conflicting option arguments on the HTTP layer' do
    options = URLCanonicalize::Options.new

    expect { URLCanonicalize::HTTP.new(url, options: options, open_timeout: 1) }
      .to raise_error(ArgumentError, 'Pass either options: or keyword options, not both')
  end
end
