# frozen_string_literal: true

describe URLCanonicalize::Options do
  subject(:options) { options_class.new }

  let(:options_class) { described_class }
  let(:overrides) do
    {
      allow_private_networks: true,
      allowed_ports: [3000],
      max_body_bytes: 2048,
      total_timeout: 10,
      open_timeout: 2,
      read_timeout: 3,
      write_timeout: 4,
      max_redirects: 5
    }
  end

  it 'uses secure defaults' do
    expect(options.to_h).to include(
      allow_private_networks: false,
      allowed_ports: [80, 443],
      max_body_bytes: 1_048_576,
      total_timeout: 30,
      open_timeout: 8,
      read_timeout: 15,
      write_timeout: 8,
      max_redirects: 10
    )
  end

  it 'accepts supported overrides' do
    expect(options_class.new(**overrides).to_h).to include(overrides)
  end

  it 'accepts replacement request headers' do
    headers = { 'User-Agent' => 'my-crawler/1.0' }

    expect(options_class.new(headers: headers).to_h).to include(headers: headers)
  end

  it 'rejects headers that are not string pairs' do
    [{ 'User-Agent' => :symbol }, { accept: 'text/html' }, %w[not a hash]].each do |headers|
      expect { options_class.new(headers: headers) }
        .to raise_error(ArgumentError, 'headers must be a Hash of String keys and String values')
    end
  end

  it 'rejects loggers that cannot log' do
    expect { options_class.new(logger: 'stdout') }
      .to raise_error(ArgumentError, 'logger must respond to debug')
  end

  it 'rejects transports that cannot be called' do
    expect { options_class.new(transport: 'net/http') }
      .to raise_error(ArgumentError, 'transport must respond to call')
  end

  it 'rejects unknown options' do
    expect { options_class.new(unknown: true) }
      .to raise_error(ArgumentError, 'Unknown options: unknown')
  end

  it 'rejects non-positive limits' do
    %i[max_body_bytes total_timeout open_timeout read_timeout write_timeout max_redirects].each do |name|
      expect { options_class.new(name => 0) }
        .to raise_error(ArgumentError, "#{name} must be positive")
    end
  end

  it 'rejects invalid ports' do
    expect { options_class.new(allowed_ports: [0, 65_536]) }
      .to raise_error(ArgumentError, 'allowed_ports must contain only valid TCP ports')
  end

  it 'rejects non-boolean private network settings' do
    expect { options_class.new(allow_private_networks: 'yes') }
      .to raise_error(ArgumentError, 'allow_private_networks must be true or false')
  end

  it 'returns defensive copies of mutable values' do
    values = options.to_h
    values[:allowed_ports] << 3000
    values[:headers]['X-Injected'] = 'true'

    expect([options[:allowed_ports], options[:headers].key?('X-Injected')]).to eq([[80, 443], false])
  end

  describe URLCanonicalize do
    context 'when fetching a URL' do
      it 'forwards security options to the HTTP operation' do
        expect { described_class.fetch('https://example.com', unknown: true) }
          .to raise_error(ArgumentError, 'Unknown options: unknown')
      end
    end
  end
end
