module URI
  # URI having the HTTP protocol
  class HTTP
    include URLCanonicalize::URI
  end

  # URI having the HTTPS protocol
  class HTTPS
    include URLCanonicalize::URI
  end
end
