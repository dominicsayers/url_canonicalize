describe URLCanonicalize::Exception do
  it 'raises the expected exception' do
    expect do
      raise URLCanonicalize::Exception::URI, 'test message'
    end.to raise_error(URLCanonicalize::Exception::URI, 'test message')

    expect do
      raise URLCanonicalize::Exception::Redirect, 'test message'
    end.to raise_error(URLCanonicalize::Exception::Redirect, 'test message')
  end
end
