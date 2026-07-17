# frozen_string_literal: true

describe URLCanonicalize::Destination do
  subject(:resolve) { destination_class.resolve(uri, options) }

  let(:destination_class) { described_class }
  let(:uri) { URI('http://example.com') }
  let(:options) { URLCanonicalize::Options.new }
  let(:addresses) { [addrinfo('93.184.216.34')] }

  before do
    allow(Addrinfo).to receive(:getaddrinfo)
      .with(uri.host, uri.port, nil, Socket::SOCK_STREAM)
      .and_return(addresses)
  end

  def addrinfo(address, port = 80)
    Addrinfo.tcp(address, port)
  end

  it 'returns a resolved public IPv4 address' do
    expect(resolve).to eq('93.184.216.34')
  end

  it 'returns a resolved public IPv6 address' do
    allow(Addrinfo).to receive(:getaddrinfo)
      .and_return([addrinfo('2606:2800:220:1:248:1893:25c8:1946')])

    expect(resolve).to eq('2606:2800:220:1:248:1893:25c8:1946')
  end

  it 'returns an allocated public IPv6 address from a narrower IANA prefix' do
    allow(Addrinfo).to receive(:getaddrinfo)
      .and_return([addrinfo('2001:4860:4860::8888')])

    expect(resolve).to eq('2001:4860:4860::8888')
  end

  [
    '0.0.0.0',
    '10.0.0.1',
    '100.64.0.1',
    '127.0.0.1',
    '169.254.169.254',
    '172.16.0.1',
    '192.0.2.1',
    '192.168.0.1',
    '198.18.0.1',
    '224.0.0.1',
    '240.0.0.1',
    '::',
    '::1',
    'fc00::1',
    'fe80::1',
    'ff00::1',
    '2001:db8::1',
    '2002::1',
    '2004::1',
    '2d00::1',
    '2e00::1',
    '3000::1',
    '3800::1',
    '3c00::1',
    '3e00::1',
    '3f00::1',
    '3ffe::1',
    '3fff::1',
    '::ffff:127.0.0.1'
  ].each do |address|
    it "rejects the non-public address #{address}" do
      allow(Addrinfo).to receive(:getaddrinfo).and_return([addrinfo(address)])

      expect { resolve }
        .to raise_error(URLCanonicalize::Exception::Security, /#{Regexp.escape(address)}/)
    end
  end

  it 'rejects a hostname when any resolved address is non-public' do
    allow(Addrinfo).to receive(:getaddrinfo)
      .and_return([addrinfo('93.184.216.34'), addrinfo('127.0.0.1')])

    expect { resolve }
      .to raise_error(URLCanonicalize::Exception::Security, /127\.0\.0\.1/)
  end

  it 'allows a private address with an explicit opt-in' do
    allow(Addrinfo).to receive(:getaddrinfo).and_return([addrinfo('127.0.0.1')])
    options = URLCanonicalize::Options.new(allow_private_networks: true)

    expect(destination_class.resolve(uri, options)).to eq('127.0.0.1')
  end

  it 'rejects userinfo without resolving the hostname' do
    uri = URI('http://user:secret@example.com')
    allow(Addrinfo).to receive(:getaddrinfo).and_raise('DNS resolution should not run')

    expect { destination_class.resolve(uri, options) }
      .to raise_error(URLCanonicalize::Exception::Security, 'URLs containing userinfo are not allowed')
  end

  it 'rejects a port that is not allowed' do
    uri = URI('http://example.com:3000')

    expect { destination_class.resolve(uri, options) }
      .to raise_error(URLCanonicalize::Exception::Security, 'Port 3000 is not allowed')
  end

  it 'allows an explicitly configured port' do
    uri = URI('http://example.com:3000')
    options = URLCanonicalize::Options.new(allowed_ports: [3000])
    allow(Addrinfo).to receive(:getaddrinfo).and_return([addrinfo('93.184.216.34', 3000)])

    expect(destination_class.resolve(uri, options)).to eq('93.184.216.34')
  end

  it 'rejects an empty DNS result' do
    allow(Addrinfo).to receive(:getaddrinfo).and_return([])

    expect { resolve }.to raise_error(SocketError, 'No addresses found for example.com')
  end

  it 'preserves resolver failures' do
    allow(Addrinfo).to receive(:getaddrinfo).and_raise(SocketError, 'DNS failed')

    expect { resolve }.to raise_error(SocketError, 'DNS failed')
  end
end
