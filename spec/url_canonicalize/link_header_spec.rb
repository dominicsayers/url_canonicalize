# frozen_string_literal: true

describe URLCanonicalize::LinkHeader do
  def response_with_links(*fields)
    response = Net::HTTPOK.new('1.1', '200', '')
    fields.each { |field| response.add_field('Link', field) }
    response
  end

  it 'finds a canonical link with a quoted rel' do
    response = response_with_links('<https://example.com/>; rel="canonical"')
    expect(described_class.canonical(response)).to eq('https://example.com/')
  end

  it 'finds a canonical link with an unquoted rel' do
    response = response_with_links('<https://example.com/>; rel=canonical')
    expect(described_class.canonical(response)).to eq('https://example.com/')
  end

  it 'matches rel values case-insensitively' do
    response = response_with_links('<https://example.com/>; REL="Canonical"')
    expect(described_class.canonical(response)).to eq('https://example.com/')
  end

  it 'matches canonical within a list of rel tokens' do
    response = response_with_links('<https://example.com/>; rel="canonical nofollow"')
    expect(described_class.canonical(response)).to eq('https://example.com/')
  end

  it 'does not match rel tokens that merely contain canonical' do
    response = response_with_links('<https://example.com/>; rel="not-canonical"')
    expect(described_class.canonical(response)).to be_nil
  end

  it 'finds the canonical link among multiple links in one header' do
    response = response_with_links(
      '<https://example.com/style.css>; rel="stylesheet", <https://example.com/>; rel="canonical"'
    )
    expect(described_class.canonical(response)).to eq('https://example.com/')
  end

  it 'finds the canonical link across multiple Link headers' do
    response = response_with_links(
      '<https://example.com/alternate>; rel="alternate"',
      '<https://example.com/>; rel="canonical"'
    )
    expect(described_class.canonical(response)).to eq('https://example.com/')
  end

  it 'is not confused by quoted parameters containing commas or angle brackets' do
    response = response_with_links(
      '<https://example.com/other>; title="a, <b>"; rel="alternate", <https://example.com/>; rel="canonical"'
    )
    expect(described_class.canonical(response)).to eq('https://example.com/')
  end

  it 'returns nil when no link is canonical' do
    response = response_with_links('<https://example.com/alternate>; rel="alternate"')
    expect(described_class.canonical(response)).to be_nil
  end

  it 'returns nil when a link has no rel parameter' do
    response = response_with_links('<https://example.com/>')
    expect(described_class.canonical(response)).to be_nil
  end

  it 'returns nil when there is no Link header' do
    expect(described_class.canonical(Net::HTTPOK.new('1.1', '200', ''))).to be_nil
  end
end
