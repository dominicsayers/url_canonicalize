# frozen_string_literal: true

describe URLCanonicalize::BoundedBody do
  it 'accepts chunks up to the byte limit' do
    body = described_class.new(5)

    body << '12' << '345'

    expect(body).to eq('12345')
  end

  it 'applies the limit to bytes rather than characters' do
    body = described_class.new(4)

    body << '££'

    expect { body << '£' }.to raise_error(URLCanonicalize::Exception::ResponseTooLarge)
  end

  it 'rejects a chunk before it would exceed the limit' do
    body = described_class.new(5)
    body << '1234'

    expect { body << '56' }.to raise_error(
      URLCanonicalize::Exception::ResponseTooLarge,
      'Response body exceeds 5 bytes'
    )
    expect(body).to eq('1234')
  end
end
